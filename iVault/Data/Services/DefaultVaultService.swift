//
//  DefaultVaultService.swift
//  iVault
//
//  Created by Tu on 28/7/26.
//

import Foundation

actor DefaultVaultService: VaultServicing, VaultBackupDataTransferring {
    private static let keyVersion = 1
    private static let imageByteLimit: Int64 = 25 * 1_024 * 1_024

    private let repository: any VaultRepository
    private let keyStore: any VaultKeyStoring
    private let crypto: VaultCryptoService
    private let assetStore: EncryptedAssetStore
    private var session: VaultSession?

    init(
        repository: any VaultRepository,
        keyStore: any VaultKeyStoring,
        crypto: VaultCryptoService,
        assetStore: EncryptedAssetStore
    ) {
        self.repository = repository
        self.keyStore = keyStore
        self.crypto = crypto
        self.assetStore = assetStore
    }

    var isUnlocked: Bool {
        session != nil
    }

    func unlock() async throws {
        if session != nil { return }

        do {
            if let state = try await repository.fetchStoreState() {
                let rawKey = try await keyStore.loadMasterKey(
                    keyID: state.activeKeyID,
                    reason: "Authenticate to unlock iVault."
                )
                let masterKey = try await crypto.restoreMasterKey(from: rawKey)
                session = VaultSession(
                    generationID: state.activeGenerationID,
                    keyID: state.activeKeyID,
                    masterKey: masterKey
                )
            } else {
                let masterKey = await crypto.generateMasterKey()
                let keyID = UUID()
                let generationID = UUID()
                try await keyStore.saveMasterKey(masterKey.rawData, keyID: keyID)
                try await repository.saveStoreState(
                    VaultStoreState(
                        activeGenerationID: generationID,
                        activeKeyID: keyID,
                        updatedAt: .now
                    )
                )
                session = VaultSession(
                    generationID: generationID,
                    keyID: keyID,
                    masterKey: masterKey
                )
            }
        } catch {
            throw map(error)
        }
    }

    func lock() {
        session = nil
    }

    func fetchItemSummaries() async throws -> [VaultItemSummary] {
        let session = try requireSession()
        do {
            let records = try await repository.fetchRecords(
                generationID: session.generationID
            )
            let summaries = try await records.asyncMap { record in
                let summary = try await self.crypto.open(
                    DecryptedVaultSummary.self,
                    envelope: record.summaryEnvelope,
                    recordID: record.id,
                    generationID: session.generationID,
                    purpose: .summary,
                    masterKey: session.masterKey
                )
                return VaultItemSummary(
                    id: record.id,
                    kind: summary.kind,
                    title: summary.title,
                    subtitle: summary.subtitle,
                    modifiedAt: summary.modifiedAt
                )
            }
            return summaries.sorted { $0.modifiedAt > $1.modifiedAt }
        } catch {
            throw map(error)
        }
    }

    func fetchEntry(id: UUID) async throws -> VaultEntry {
        let session = try requireSession()
        do {
            guard let record = try await repository.fetchRecord(
                id: id,
                generationID: session.generationID
            ) else {
                throw VaultError.itemNotFound(id: id)
            }
            let decrypted = try await crypto.open(
                DecryptedVaultRecord.self,
                envelope: record.payloadEnvelope,
                recordID: id,
                generationID: session.generationID,
                purpose: .payload,
                masterKey: session.masterKey
            )
            return VaultEntry(
                id: id,
                createdAt: decrypted.createdAt,
                modifiedAt: decrypted.modifiedAt,
                payload: decrypted.payload
            )
        } catch {
            throw map(error)
        }
    }

    func createEntry(from draft: VaultItemDraft) async throws -> UUID {
        let session = try requireSession()
        try validate(draft)
        let id = UUID()
        let now = Date()
        let prepared = try await preparePayload(
            draft,
            session: session,
            preserving: nil
        )
        do {
            try await save(
                id: id,
                createdAt: now,
                modifiedAt: now,
                revision: 1,
                payload: prepared.payload,
                session: session
            )
            return id
        } catch {
            await removeNewAssetIfNeeded(prepared, session: session)
            throw map(error)
        }
    }

    func updateEntry(id: UUID, with draft: VaultItemDraft) async throws {
        let session = try requireSession()
        try validate(draft)
        let existing = try await fetchEntry(id: id)
        let stored = try await repository.fetchRecord(
            id: id,
            generationID: session.generationID
        )
        let prepared = try await preparePayload(
            draft,
            session: session,
            preserving: existing.payload
        )
        do {
            try await save(
                id: id,
                createdAt: existing.createdAt,
                modifiedAt: .now,
                revision: (stored?.revision ?? 0) + 1,
                payload: prepared.payload,
                session: session
            )
            if let oldAssetID = imageAssetID(in: existing.payload),
               oldAssetID != imageAssetID(in: prepared.payload) {
                try? await repository.deleteAsset(
                    id: oldAssetID,
                    generationID: session.generationID
                )
                try? await assetStore.delete(assetID: oldAssetID)
            }
        } catch {
            await removeNewAssetIfNeeded(prepared, session: session)
            throw map(error)
        }
    }

    func deleteEntry(id: UUID) async throws {
        let session = try requireSession()
        let entry = try await fetchEntry(id: id)
        do {
            try await repository.deleteRecord(
                id: id,
                generationID: session.generationID
            )
            if let assetID = imageAssetID(in: entry.payload) {
                try? await repository.deleteAsset(
                    id: assetID,
                    generationID: session.generationID
                )
                try? await assetStore.delete(assetID: assetID)
            }
        } catch {
            throw map(error)
        }
    }

    func fetchImageData(assetID: UUID) async throws -> Data {
        let session = try requireSession()
        do {
            guard let asset = try await repository.fetchAsset(
                id: assetID,
                generationID: session.generationID
            ) else {
                throw VaultError.assetNotFound(id: assetID)
            }
            let ciphertext = try await assetStore.read(assetID: assetID)
            return try await crypto.openAsset(
                package: EncryptedAssetPackage(
                    ciphertextCombined: ciphertext,
                    wrappedKey: asset.wrappedKey
                ),
                assetID: assetID,
                generationID: session.generationID,
                masterKey: session.masterKey
            )
        } catch {
            throw map(error)
        }
    }

    func exportBackupSnapshot() async throws -> VaultBackupSnapshot {
        let session = try requireSession()
        do {
            let records = try await repository.fetchRecords(
                generationID: session.generationID
            )
            let assets = try await repository.fetchAssets(
                generationID: session.generationID
            )
            let encryptedAssets = try await assets.asyncMap { asset in
                VaultBackupAsset(
                    metadata: asset,
                    ciphertext: try await self.assetStore.read(assetID: asset.id)
                )
            }
            return VaultBackupSnapshot(
                sourceGenerationID: session.generationID,
                masterKeyData: session.masterKey.rawData,
                records: records,
                assets: encryptedAssets
            )
        } catch {
            throw map(error)
        }
    }

    func replaceVault(with snapshot: VaultBackupSnapshot) async throws {
        do {
            let restoredMasterKey = try await crypto.restoreMasterKey(
                from: snapshot.masterKeyData
            )
            try await validate(snapshot: snapshot, masterKey: restoredMasterKey)
            let newKeyID = UUID()
            try await keyStore.saveMasterKey(snapshot.masterKeyData, keyID: newKeyID)

            for asset in snapshot.assets {
                try await assetStore.write(
                    ciphertext: asset.ciphertext,
                    assetID: asset.metadata.id
                )
                try await repository.upsertAsset(asset.metadata)
            }
            for record in snapshot.records {
                try await repository.upsertRecord(record)
            }
            try await repository.saveStoreState(
                VaultStoreState(
                    activeGenerationID: snapshot.sourceGenerationID,
                    activeKeyID: newKeyID,
                    updatedAt: .now
                )
            )
            session = VaultSession(
                generationID: snapshot.sourceGenerationID,
                keyID: newKeyID,
                masterKey: restoredMasterKey
            )
        } catch {
            throw map(error)
        }
    }

    private func save(
        id: UUID,
        createdAt: Date,
        modifiedAt: Date,
        revision: Int64,
        payload: VaultPayload,
        session: VaultSession
    ) async throws {
        let summary = makeSummary(for: payload, modifiedAt: modifiedAt)
        let summaryEnvelope = try await crypto.seal(
            summary,
            recordID: id,
            generationID: session.generationID,
            purpose: .summary,
            keyVersion: Self.keyVersion,
            masterKey: session.masterKey
        )
        let payloadEnvelope = try await crypto.seal(
            DecryptedVaultRecord(
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                payload: payload
            ),
            recordID: id,
            generationID: session.generationID,
            purpose: .payload,
            keyVersion: Self.keyVersion,
            masterKey: session.masterKey
        )
        try await repository.upsertRecord(
            StoredVaultRecord(
                id: id,
                generationID: session.generationID,
                modifiedAt: modifiedAt,
                revision: revision,
                summaryEnvelope: summaryEnvelope,
                payloadEnvelope: payloadEnvelope
            )
        )
    }

    private func preparePayload(
        _ draft: VaultItemDraft,
        session: VaultSession,
        preserving existingPayload: VaultPayload?
    ) async throws -> PreparedPayload {
        switch draft {
        case .login(let login):
            return PreparedPayload(
                payload: .login(
                    LoginSecret(
                        title: login.title.trimmed,
                        username: login.username.trimmed,
                        password: login.password,
                        website: login.website.trimmed.nilIfEmpty,
                        notes: login.notes.trimmed.nilIfEmpty
                    )
                )
            )
        case .secureNote(let note):
            return PreparedPayload(
                payload: .secureNote(
                    SecureNote(title: note.title.trimmed, body: note.body)
                )
            )
        case .image(let image):
            if let imageData = image.imageData {
                let assetID = UUID()
                let package = try await crypto.sealAsset(
                    imageData,
                    assetID: assetID,
                    generationID: session.generationID,
                    keyVersion: Self.keyVersion,
                    masterKey: session.masterKey
                )
                do {
                    try await assetStore.write(
                        ciphertext: package.ciphertextCombined,
                        assetID: assetID
                    )
                    try await repository.upsertAsset(
                        StoredVaultAsset(
                            id: assetID,
                            generationID: session.generationID,
                            byteCount: Int64(imageData.count),
                            wrappedKey: package.wrappedKey
                        )
                    )
                } catch {
                    try? await assetStore.delete(assetID: assetID)
                    try? await repository.deleteAsset(
                        id: assetID,
                        generationID: session.generationID
                    )
                    throw error
                }
                return PreparedPayload(
                    payload: .image(
                        SecureImage(
                            title: image.title.trimmed,
                            assetID: assetID,
                            originalFilename: image.originalFilename?.trimmed.nilIfEmpty,
                            mediaType: image.mediaType?.trimmed.nilIfEmpty,
                            byteCount: Int64(imageData.count),
                            notes: image.notes.trimmed.nilIfEmpty
                        )
                    ),
                    newAssetID: assetID
                )
            }
            guard case .image(let preservedImage) = existingPayload else {
                throw VaultError.invalidDraft(.requiredField(.imageData))
            }
            return PreparedPayload(
                payload: .image(
                    SecureImage(
                        title: image.title.trimmed,
                        assetID: preservedImage.assetID,
                        originalFilename: image.originalFilename?.trimmed.nilIfEmpty,
                        mediaType: image.mediaType?.trimmed.nilIfEmpty,
                        byteCount: preservedImage.byteCount,
                        notes: image.notes.trimmed.nilIfEmpty
                    )
                )
            )
        }
    }

    private func validate(_ draft: VaultItemDraft) throws {
        switch draft {
        case .login(let login):
            guard !login.title.trimmed.isEmpty else {
                throw VaultError.invalidDraft(.requiredField(.title))
            }
            guard !login.password.isEmpty else {
                throw VaultError.invalidDraft(.requiredField(.password))
            }
            if !login.website.trimmed.isEmpty,
               !isValidWebsite(login.website.trimmed) {
                throw VaultError.invalidDraft(.invalidWebsite)
            }
        case .secureNote(let note):
            guard !note.title.trimmed.isEmpty else {
                throw VaultError.invalidDraft(.requiredField(.title))
            }
            guard !note.body.trimmed.isEmpty else {
                throw VaultError.invalidDraft(.requiredField(.noteBody))
            }
        case .image(let image):
            guard !image.title.trimmed.isEmpty else {
                throw VaultError.invalidDraft(.requiredField(.title))
            }
            if let imageData = image.imageData,
               Int64(imageData.count) > Self.imageByteLimit {
                throw VaultError.invalidDraft(
                    .imageExceedsSizeLimit(maximumBytes: Self.imageByteLimit)
                )
            }
        }
    }

    private func validate(
        snapshot: VaultBackupSnapshot,
        masterKey: VaultMasterKey
    ) async throws {
        for record in snapshot.records {
            _ = try await crypto.open(
                DecryptedVaultRecord.self,
                envelope: record.payloadEnvelope,
                recordID: record.id,
                generationID: snapshot.sourceGenerationID,
                purpose: .payload,
                masterKey: masterKey
            )
            _ = try await crypto.open(
                DecryptedVaultSummary.self,
                envelope: record.summaryEnvelope,
                recordID: record.id,
                generationID: snapshot.sourceGenerationID,
                purpose: .summary,
                masterKey: masterKey
            )
        }
        for asset in snapshot.assets {
            _ = try await crypto.openAsset(
                package: EncryptedAssetPackage(
                    ciphertextCombined: asset.ciphertext,
                    wrappedKey: asset.metadata.wrappedKey
                ),
                assetID: asset.metadata.id,
                generationID: snapshot.sourceGenerationID,
                masterKey: masterKey
            )
        }
    }

    private func makeSummary(
        for payload: VaultPayload,
        modifiedAt: Date
    ) -> DecryptedVaultSummary {
        switch payload {
        case .login(let login):
            DecryptedVaultSummary(
                kind: .login,
                title: login.title,
                subtitle: login.username.nilIfEmpty ?? login.website,
                modifiedAt: modifiedAt
            )
        case .secureNote(let note):
            DecryptedVaultSummary(
                kind: .secureNote,
                title: note.title,
                subtitle: note.body.truncated(to: 90).nilIfEmpty,
                modifiedAt: modifiedAt
            )
        case .image(let image):
            DecryptedVaultSummary(
                kind: .image,
                title: image.title,
                subtitle: image.originalFilename,
                modifiedAt: modifiedAt
            )
        }
    }

    private func removeNewAssetIfNeeded(
        _ prepared: PreparedPayload,
        session: VaultSession
    ) async {
        guard let assetID = prepared.newAssetID else { return }
        try? await assetStore.delete(assetID: assetID)
        try? await repository.deleteAsset(
            id: assetID,
            generationID: session.generationID
        )
    }

    private func requireSession() throws -> VaultSession {
        guard let session else { throw VaultError.locked }
        return session
    }

    private func imageAssetID(in payload: VaultPayload) -> UUID? {
        guard case .image(let image) = payload else { return nil }
        return image.assetID
    }

    private func isValidWebsite(_ value: String) -> Bool {
        let normalized = value.contains("://") ? value : "https://\(value)"
        guard let components = URLComponents(string: normalized),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              !(components.host?.isEmpty ?? true) else {
            return false
        }
        return true
    }

    private func map(_ error: Error) -> VaultError {
        if let vaultError = error as? VaultError { return vaultError }
        if let keychainError = error as? VaultKeyStoreError {
            switch keychainError {
            case .itemNotFound: return .keyUnavailable
            case .authenticationCancelled: return .authenticationCancelled
            case .authenticationFailed, .interactionNotAllowed: return .authenticationFailed
            default: return .keyUnavailable
            }
        }
        if error is VaultCryptoServiceError { return .corruptedPayload }
        if error is EncryptedAssetStoreError { return .storageUnavailable }
        return .operationFailed
    }
}

private struct VaultSession: Sendable {
    let generationID: UUID
    let keyID: UUID
    let masterKey: VaultMasterKey
}

private struct PreparedPayload: Sendable {
    let payload: VaultPayload
    var newAssetID: UUID?
}

private extension String {
    nonisolated var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    nonisolated func truncated(to count: Int) -> String {
        String(prefix(count))
    }
}

private extension Array where Element: Sendable {
    nonisolated func asyncMap<T: Sendable>(
        _ transform: @Sendable (Element) async throws -> T
    ) async throws -> [T] {
        var values: [T] = []
        values.reserveCapacity(count)
        for element in self {
            try Task.checkCancellation()
            values.append(try await transform(element))
        }
        return values
    }
}
