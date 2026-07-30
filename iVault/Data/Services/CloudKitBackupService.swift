@preconcurrency import CloudKit
import Foundation
import OSLog

actor CloudKitBackupService: BackupServicing {
    private static let logger = Logger(
        subsystem: "com.dev.ivault",
        category: "CloudKitBackup"
    )

    private enum Field {
        static let backupID = "backupID"
        static let createdAt = "createdAt"
        static let completedAt = "completedAt"
        static let state = "state"
        static let recordCount = "recordCount"
        static let assetCount = "assetCount"
        static let encryptedByteCount = "encryptedByteCount"
        static let formatVersion = "formatVersion"
        static let appVersion = "appVersion"
        static let manifestEnvelopeVersion = "manifestEnvelopeVersion"
        static let manifestKeyVersion = "manifestKeyVersion"
        static let manifestCiphertext = "manifestCiphertext"
        static let assetID = "assetID"
        static let ciphertext = "ciphertext"
    }

    private static let backupRecordType = "VaultBackup"
    private static let assetRecordType = "VaultBackupAsset"
    private static let formatVersion = 1
    private static let keyVersion = 1

    private let vaultTransfer: any VaultBackupDataTransferring
    private let backupKeyStore: any BackupKeyStoring
    private let crypto: VaultCryptoService
    private let container: CKContainer
    private let database: CKDatabase
    private let zoneID = CKRecordZone.ID(zoneName: "iVaultBackups")

    init(
        vaultTransfer: any VaultBackupDataTransferring,
        backupKeyStore: any BackupKeyStoring,
        crypto: VaultCryptoService,
        containerIdentifier: String = "iCloud.com.dev.ivault"
    ) {
        self.vaultTransfer = vaultTransfer
        self.backupKeyStore = backupKeyStore
        self.crypto = crypto
        container = CKContainer(identifier: containerIdentifier)
        database = container.privateCloudDatabase
    }

    func fetchAvailableBackups() async throws -> [BackupInfo] {
        do {
            try await requireAccount()
            try await ensureZone()
            let query = CKQuery(
                recordType: Self.backupRecordType,
                predicate: NSPredicate(
                    format: "%K > %@",
                    Field.createdAt,
                    Date(timeIntervalSince1970: 0) as NSDate
                )
            )
            #if DEBUG
            print("[CloudKitBackup] fetch predicate: createdAt > 1970-01-01")
            #endif
            query.sortDescriptors = [
                NSSortDescriptor(key: Field.createdAt, ascending: false)
            ]
            return try await allRecords(matching: query).compactMap(makeBackupInfo)
                .filter(\.isRestorable)
        } catch {
            // A brand-new Development container has no VaultBackup record type
            // until the first record is saved. Treat that state as an empty list.
            if isMissingSchemaError(error) {
                return []
            }
            log(error, operation: "fetch backups")
            throw map(error)
        }
    }

    func createBackup() async throws -> BackupCreationResult {
        let backupID = UUID()
        var snapshot: VaultBackupSnapshot?
        var didStartCloudUpload = false
        var didStoreBackupKey = false

        do {
            try await requireAccount()
            try await ensureZone()
            let exportedSnapshot = try await vaultTransfer.exportBackupSnapshot()
            snapshot = exportedSnapshot
            let backupKey = await crypto.generateMasterKey()
            let wrappedMasterKey = try await crypto.seal(
                exportedSnapshot.masterKeyData,
                recordID: backupID,
                generationID: backupID,
                purpose: .backupMasterKey,
                keyVersion: Self.keyVersion,
                masterKey: backupKey
            )
            let manifest = VaultBackupManifest(
                formatVersion: Self.formatVersion,
                backupID: backupID,
                createdAt: .now,
                sourceGenerationID: exportedSnapshot.sourceGenerationID,
                wrappedMasterKey: wrappedMasterKey,
                records: exportedSnapshot.records,
                assets: exportedSnapshot.assets.map(\.metadata)
            )
            let encryptedManifest = try await crypto.seal(
                manifest,
                recordID: backupID,
                generationID: backupID,
                purpose: .backupManifest,
                keyVersion: Self.keyVersion,
                masterKey: backupKey
            )

            do {
                try await backupKeyStore.saveBackupKey(
                    backupKey.rawData,
                    backupID: backupID
                )
                didStoreBackupKey = true
            } catch {
                // iCloud Keychain is an optional convenience. The recovery code
                // remains the authoritative fallback and is shown after upload.
                log(error, operation: "store synchronized backup key")
            }

            let info = makeBackupInfo(
                id: backupID,
                createdAt: manifest.createdAt,
                completedAt: nil,
                state: .uploading,
                snapshot: exportedSnapshot
            )
            didStartCloudUpload = true
            let uploadingRecord = try await saveBackupRecord(
                info: info,
                manifestEnvelope: encryptedManifest
            )

            for asset in exportedSnapshot.assets {
                try Task.checkCancellation()
                try await saveAssetRecord(asset, backupID: backupID)
            }

            let completeInfo = BackupInfo(
                id: info.id,
                createdAt: info.createdAt,
                completedAt: .now,
                state: .complete,
                recordCount: info.recordCount,
                assetCount: info.assetCount,
                encryptedByteCount: info.encryptedByteCount,
                formatVersion: info.formatVersion,
                appVersion: info.appVersion
            )
            _ = try await saveBackupRecord(
                info: completeInfo,
                manifestEnvelope: encryptedManifest,
                existingRecord: uploadingRecord
            )
            return BackupCreationResult(
                backup: completeInfo,
                recoveryCode: BackupRecoveryCode.encode(backupKey.rawData)
            )
        } catch is CancellationError {
            if didStartCloudUpload {
                await cleanupFailedBackup(id: backupID, snapshot: snapshot)
            }
            if didStoreBackupKey {
                try? await backupKeyStore.deleteBackupKey(backupID: backupID)
            }
            throw BackupError.cancelled
        } catch {
            log(error, operation: "create backup")
            if didStartCloudUpload {
                await cleanupFailedBackup(id: backupID, snapshot: snapshot)
            }
            if didStoreBackupKey {
                try? await backupKeyStore.deleteBackupKey(backupID: backupID)
            }
            throw map(error)
        }
    }

    func restoreBackup(
        id: UUID,
        using recoveryMethod: BackupRecoveryMethod
    ) async throws {
        do {
            try await requireAccount()
            try await ensureZone()
            let backupRecord = try await fetchBackupRecord(id: id)
            guard let info = makeBackupInfo(from: backupRecord) else {
                throw BackupError.downloadFailed
            }
            guard info.state == .complete else {
                throw BackupError.backupIncomplete(id: id)
            }
            guard info.formatVersion == Self.formatVersion else {
                throw BackupError.unsupportedFormat(version: info.formatVersion)
            }

            let backupKeyData = try await resolveBackupKey(
                backupID: id,
                recoveryMethod: recoveryMethod
            )
            let backupKey = try await crypto.restoreMasterKey(from: backupKeyData)
            let manifestEnvelope = try manifestEnvelope(from: backupRecord)
            let manifest = try await crypto.open(
                VaultBackupManifest.self,
                envelope: manifestEnvelope,
                recordID: id,
                generationID: id,
                purpose: .backupManifest,
                masterKey: backupKey
            )
            guard manifest.formatVersion == Self.formatVersion,
                  manifest.backupID == id else {
                throw BackupError.integrityCheckFailed
            }
            let masterKeyData = try await crypto.open(
                Data.self,
                envelope: manifest.wrappedMasterKey,
                recordID: id,
                generationID: id,
                purpose: .backupMasterKey,
                masterKey: backupKey
            )
            let assetCiphertexts = try await fetchAssetCiphertexts(
                backupID: id,
                expectedAssets: manifest.assets
            )
            let assets = try manifest.assets.map { metadata in
                guard let ciphertext = assetCiphertexts[metadata.id] else {
                    throw BackupError.assetMissing(id: metadata.id)
                }
                return VaultBackupAsset(metadata: metadata, ciphertext: ciphertext)
            }
            try await vaultTransfer.replaceVault(
                with: VaultBackupSnapshot(
                    sourceGenerationID: manifest.sourceGenerationID,
                    masterKeyData: masterKeyData,
                    records: manifest.records,
                    assets: assets
                )
            )
        } catch is CancellationError {
            throw BackupError.cancelled
        } catch {
            log(error, operation: "restore backup")
            throw map(error)
        }
    }

    func deleteBackup(id: UUID) async throws {
        do {
            try await requireAccount()
            try await ensureZone()
            let assetQuery = CKQuery(
                recordType: Self.assetRecordType,
                predicate: NSPredicate(format: "%K == %@", Field.backupID, id.uuidString)
            )
            let assetRecords: [CKRecord]
            do {
                assetRecords = try await allRecords(matching: assetQuery)
            } catch {
                // Backups without images never create VaultBackupAsset in a
                // Development container, so there is nothing to delete.
                if isMissingSchemaError(error) {
                    assetRecords = []
                } else {
                    throw error
                }
            }
            var recordIDs = assetRecords.map(\.recordID)
            recordIDs.append(backupRecordID(for: id))

            for ids in recordIDs.chunked(into: 100) {
                try await deleteRecords(ids)
            }
            try? await backupKeyStore.deleteBackupKey(backupID: id)
        } catch {
            log(error, operation: "delete backup")
            throw map(error)
        }
    }

    private func requireAccount() async throws {
        switch try await container.accountStatus() {
        case .available:
            return
        case .noAccount:
            throw BackupError.cloudAccountUnavailable
        case .temporarilyUnavailable:
            throw BackupError.networkUnavailable
        case .restricted, .couldNotDetermine:
            throw BackupError.cloudAccountUnavailable
        @unknown default:
            throw BackupError.cloudAccountUnavailable
        }
    }

    private func ensureZone() async throws {
        let results = try await database.recordZones(for: [zoneID])
        if let result = results[zoneID] {
            switch result {
            case .success:
                return
            case .failure(let error):
                guard let cloudError = error as? CKError,
                      cloudError.code == .zoneNotFound else {
                    throw error
                }
            }
        }

        let saved = try await database.modifyRecordZones(
            saving: [CKRecordZone(zoneID: zoneID)],
            deleting: []
        )
        guard let result = saved.saveResults[zoneID] else {
            throw BackupError.uploadFailed
        }
        _ = try result.get()
    }

    private func saveBackupRecord(
        info: BackupInfo,
        manifestEnvelope: EncryptedEnvelope,
        existingRecord: CKRecord? = nil
    ) async throws -> CKRecord {
        let record: CKRecord
        let savePolicy: CKModifyRecordsOperation.RecordSavePolicy
        if let existingRecord {
            record = existingRecord
            savePolicy = .changedKeys
        } else {
            record = CKRecord(
                recordType: Self.backupRecordType,
                recordID: backupRecordID(for: info.id)
            )
            savePolicy = .allKeys
        }
        record[Field.backupID] = info.id.uuidString as CKRecordValue
        record[Field.createdAt] = info.createdAt as CKRecordValue
        record[Field.completedAt] = info.completedAt as CKRecordValue?
        record[Field.state] = info.state.rawValue as CKRecordValue
        record[Field.recordCount] = info.recordCount as CKRecordValue
        record[Field.assetCount] = info.assetCount as CKRecordValue
        record[Field.encryptedByteCount] = info.encryptedByteCount as CKRecordValue
        record[Field.formatVersion] = info.formatVersion as CKRecordValue
        record[Field.appVersion] = info.appVersion as CKRecordValue
        record[Field.manifestEnvelopeVersion] = manifestEnvelope.formatVersion as CKRecordValue
        record[Field.manifestKeyVersion] = manifestEnvelope.keyVersion as CKRecordValue
        record[Field.manifestCiphertext] = manifestEnvelope.combined as CKRecordValue
        return try await save(record, policy: savePolicy)
    }

    private func saveAssetRecord(
        _ asset: VaultBackupAsset,
        backupID: UUID
    ) async throws {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ivault-\(backupID.uuidString)-\(asset.metadata.id.uuidString).asset")
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        try asset.ciphertext.write(to: temporaryURL, options: .atomic)

        let record = CKRecord(
            recordType: Self.assetRecordType,
            recordID: assetRecordID(for: asset.metadata.id, backupID: backupID)
        )
        record[Field.backupID] = backupID.uuidString as CKRecordValue
        record[Field.assetID] = asset.metadata.id.uuidString as CKRecordValue
        record[Field.ciphertext] = CKAsset(fileURL: temporaryURL)
        _ = try await save(record, policy: .allKeys)
    }

    private func fetchBackupRecord(id: UUID) async throws -> CKRecord {
        let results = try await database.records(for: [backupRecordID(for: id)])
        guard let result = results[backupRecordID(for: id)] else {
            throw BackupError.backupNotFound(id: id)
        }
        do {
            return try result.get()
        } catch let error as CKError where error.code == .unknownItem {
            throw BackupError.backupNotFound(id: id)
        }
    }

    private func fetchAssetCiphertexts(
        backupID: UUID,
        expectedAssets: [StoredVaultAsset]
    ) async throws -> [UUID: Data] {
        guard !expectedAssets.isEmpty else { return [:] }
        let query = CKQuery(
            recordType: Self.assetRecordType,
            predicate: NSPredicate(format: "%K == %@", Field.backupID, backupID.uuidString)
        )
        let records = try await allRecords(matching: query)
        var result: [UUID: Data] = [:]

        for record in records {
            guard let assetIDString = record[Field.assetID] as? String,
                  let assetID = UUID(uuidString: assetIDString),
                  let cloudAsset = record[Field.ciphertext] as? CKAsset,
                  let fileURL = cloudAsset.fileURL else {
                throw BackupError.downloadFailed
            }
            result[assetID] = try Data(contentsOf: fileURL)
        }
        return result
    }

    private func allRecords(matching query: CKQuery) async throws -> [CKRecord] {
        var fetched: [CKRecord] = []
        var page = try await database.records(
            matching: query,
            inZoneWith: zoneID,
            resultsLimit: 200
        )
        while true {
            for (_, result) in page.matchResults {
                fetched.append(try result.get())
            }
            guard let cursor = page.queryCursor else { return fetched }
            page = try await database.records(
                continuingMatchFrom: cursor,
                resultsLimit: 200
            )
        }
    }

    private func save(
        _ record: CKRecord,
        policy: CKModifyRecordsOperation.RecordSavePolicy
    ) async throws -> CKRecord {
        let response = try await database.modifyRecords(
            saving: [record],
            deleting: [],
            savePolicy: policy,
            atomically: true
        )
        guard let result = response.saveResults[record.recordID] else {
            throw BackupError.uploadFailed
        }
        return try result.get()
    }

    private func cleanupFailedBackup(
        id: UUID,
        snapshot: VaultBackupSnapshot?
    ) async {
        var recordIDs = snapshot?.assets.map {
            assetRecordID(for: $0.metadata.id, backupID: id)
        } ?? []
        recordIDs.append(backupRecordID(for: id))

        for ids in recordIDs.chunked(into: 100) {
            do {
                let response = try await database.modifyRecords(
                    saving: [],
                    deleting: ids,
                    atomically: false
                )
                for result in response.deleteResults.values {
                    do {
                        _ = try result.get()
                    } catch let cloudError as CKError where cloudError.code == .unknownItem {
                        continue
                    } catch {
                        log(error, operation: "clean up failed backup")
                    }
                }
            } catch {
                log(error, operation: "clean up failed backup")
            }
        }
    }

    private func deleteRecords(_ recordIDs: [CKRecord.ID]) async throws {
        let response = try await database.modifyRecords(
            saving: [],
            deleting: recordIDs,
            atomically: true
        )
        for recordID in recordIDs {
            guard let result = response.deleteResults[recordID] else {
                throw BackupError.uploadFailed
            }
            _ = try result.get()
        }
    }

    private func backupRecordID(for backupID: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "backup-\(backupID.uuidString.lowercased())", zoneID: zoneID)
    }

    private func assetRecordID(
        for assetID: UUID,
        backupID: UUID
    ) -> CKRecord.ID {
        CKRecord.ID(
            recordName: "asset-\(backupID.uuidString.lowercased())-\(assetID.uuidString.lowercased())",
            zoneID: zoneID
        )
    }

    private func manifestEnvelope(from record: CKRecord) throws -> EncryptedEnvelope {
        guard let version = record[Field.manifestEnvelopeVersion] as? Int,
              let keyVersion = record[Field.manifestKeyVersion] as? Int,
              let combined = record[Field.manifestCiphertext] as? Data else {
            throw BackupError.downloadFailed
        }
        return EncryptedEnvelope(
            formatVersion: version,
            keyVersion: keyVersion,
            combined: combined
        )
    }

    private func makeBackupInfo(from record: CKRecord) -> BackupInfo? {
        guard let idString = record[Field.backupID] as? String,
              let id = UUID(uuidString: idString),
              let createdAt = record[Field.createdAt] as? Date,
              let stateString = record[Field.state] as? String,
              let state = BackupState(rawValue: stateString),
              let recordCount = record[Field.recordCount] as? Int,
              let assetCount = record[Field.assetCount] as? Int,
              let encryptedByteCount = record[Field.encryptedByteCount] as? Int64,
              let formatVersion = record[Field.formatVersion] as? Int,
              let appVersion = record[Field.appVersion] as? String else {
            return nil
        }
        return BackupInfo(
            id: id,
            createdAt: createdAt,
            completedAt: record[Field.completedAt] as? Date,
            state: state,
            recordCount: recordCount,
            assetCount: assetCount,
            encryptedByteCount: encryptedByteCount,
            formatVersion: formatVersion,
            appVersion: appVersion
        )
    }

    private func makeBackupInfo(
        id: UUID,
        createdAt: Date,
        completedAt: Date?,
        state: BackupState,
        snapshot: VaultBackupSnapshot
    ) -> BackupInfo {
        let recordCiphertextBytes = snapshot.records.reduce(0) { total, record in
            total + record.summaryEnvelope.combined.count
                + record.payloadEnvelope.combined.count
        }
        let assetCiphertextBytes = snapshot.assets.reduce(0) { total, asset in
            total + asset.ciphertext.count + asset.metadata.wrappedKey.combined.count
        }
        let encryptedByteCount = Int64(recordCiphertextBytes + assetCiphertextBytes)
        let appVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0"
        return BackupInfo(
            id: id,
            createdAt: createdAt,
            completedAt: completedAt,
            state: state,
            recordCount: snapshot.records.count,
            assetCount: snapshot.assets.count,
            encryptedByteCount: encryptedByteCount,
            formatVersion: Self.formatVersion,
            appVersion: appVersion
        )
    }

    private func resolveBackupKey(
        backupID: UUID,
        recoveryMethod: BackupRecoveryMethod
    ) async throws -> Data {
        switch recoveryMethod {
        case .synchronizedKeychain:
            do {
                return try await backupKeyStore.loadBackupKey(backupID: backupID)
            } catch let error as VaultKeyStoreError where error == .itemNotFound {
                throw BackupError.recoveryKeyRequired
            }
        case .recoveryCode(let code):
            guard let data = BackupRecoveryCode.decode(code), data.count == 32 else {
                throw BackupError.invalidRecoveryKey
            }
            return data
        }
    }

    private func map(_ error: Error) -> BackupError {
        if let backupError = error as? BackupError { return backupError }
        if error is VaultCryptoServiceError { return .integrityCheckFailed }
        if let cloudError = representativeCloudError(in: error) {
            switch cloudError.code {
            case .networkFailure, .networkUnavailable, .serviceUnavailable,
                 .requestRateLimited, .zoneBusy, .accountTemporarilyUnavailable:
                return .networkUnavailable
            case .notAuthenticated:
                return .cloudAccountUnavailable
            case .quotaExceeded:
                return .quotaExceeded
            case .badContainer, .badDatabase, .missingEntitlement,
                 .permissionFailure:
                return .cloudConfigurationInvalid
            case .unknownItem:
                return .downloadFailed
            default:
                return .uploadFailed
            }
        }
        return .importFailed
    }

    private func isMissingSchemaError(_ error: Error) -> Bool {
        representativeCloudError(in: error)?.code == .unknownItem
    }

    private func representativeCloudError(in error: Error) -> CKError? {
        guard let cloudError = error as? CKError else { return nil }
        guard cloudError.code == .partialFailure,
              let partialErrors = cloudError.userInfo[
                  CKPartialErrorsByItemIDKey
              ] as? [AnyHashable: Error] else {
            return cloudError
        }
        return partialErrors.values.lazy
            .compactMap(representativeCloudError)
            .first ?? cloudError
    }

    private func log(_ error: Error, operation: String) {
        #if DEBUG
        print(
            "[CloudKitBackup] \(operation) failed: "
                + String(reflecting: error)
        )
        #endif
        Self.logger.error(
            "\(operation, privacy: .public) failed: \(String(reflecting: error), privacy: .public)"
        )
    }
}

nonisolated private struct VaultBackupManifest: Codable, Sendable {
    let formatVersion: Int
    let backupID: UUID
    let createdAt: Date
    let sourceGenerationID: UUID
    let wrappedMasterKey: EncryptedEnvelope
    let records: [StoredVaultRecord]
    let assets: [StoredVaultAsset]
}

nonisolated enum BackupRecoveryCode {
    static func encode(_ data: Data) -> String {
        let hexadecimal = data.map { String(format: "%02X", $0) }.joined()
        var groups: [String] = []
        var start = hexadecimal.startIndex
        while start < hexadecimal.endIndex {
            let end = hexadecimal.index(
                start,
                offsetBy: 4,
                limitedBy: hexadecimal.endIndex
            ) ?? hexadecimal.endIndex
            groups.append(String(hexadecimal[start ..< end]))
            start = end
        }
        return groups.joined(separator: "-")
    }

    static func decode(_ value: String) -> Data? {
        let hexadecimal = value
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard hexadecimal.count == 64 else { return nil }
        var data = Data()
        var index = hexadecimal.startIndex
        while index < hexadecimal.endIndex {
            let next = hexadecimal.index(index, offsetBy: 2)
            guard let byte = UInt8(hexadecimal[index ..< next], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = next
        }
        return data
    }
}

nonisolated private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
