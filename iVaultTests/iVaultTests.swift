//
//  iVaultTests.swift
//  iVaultTests
//
//  Created by Tu on 26/7/26.
//

import Foundation
import Testing
@testable import iVault

struct iVaultTests {

    @Test
    @MainActor
    func spacingScaleIsStrictlyIncreasing() {
        #expect(PassVaultSpacing.xSmall < PassVaultSpacing.small)
        #expect(PassVaultSpacing.small < PassVaultSpacing.medium)
        #expect(PassVaultSpacing.medium < PassVaultSpacing.large)
        #expect(PassVaultSpacing.large < PassVaultSpacing.xLarge)
    }

    @Test
    func tabBarContainsTheFourImplementedDestinations() {
        #expect(PassVaultTab.allCases.count == 4)
    }

    @Test
    func backupRecoveryCodeRoundTrips32ByteKey() {
        let key = Data(0 ..< 32)
        let code = BackupRecoveryCode.encode(key)

        #expect(code.count == 79)
        #expect(BackupRecoveryCode.decode(code) == key)
        #expect(BackupRecoveryCode.decode("not a recovery code") == nil)
    }

    @Test
    @MainActor
    func creatingBackupPublishesSnapshotAndRecoveryCode() async {
        let backup = BackupInfo(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_000_001),
            state: .complete,
            recordCount: 2,
            assetCount: 1,
            encryptedByteCount: 1_024,
            formatVersion: 1,
            appVersion: "1.0"
        )
        let service = BackupServiceStub(
            creationResult: BackupCreationResult(
                backup: backup,
                recoveryCode: "RECOVERY-CODE"
            )
        )
        let viewModel = BackupViewModel(backupService: service)

        await viewModel.createBackup()

        #expect(viewModel.backups == [backup])
        #expect(viewModel.newRecoveryCode == "RECOVERY-CODE")
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isWorking)
    }

    @Test
    @MainActor
    func cloudConfigurationFailureShowsActionableMessage() async {
        let service = BackupServiceStub(createError: .cloudConfigurationInvalid)
        let viewModel = BackupViewModel(backupService: service)

        await viewModel.createBackup()

        #expect(viewModel.backups.isEmpty)
        #expect(
            viewModel.errorMessage
                == "CloudKit is not configured for this app. Verify the iCloud capability and the iCloud.com.dev.ivault container."
        )
        #expect(!viewModel.isWorking)
    }

    @Test
    func cloudQuotaFailureShowsStorageRecoveryAction() {
        #expect(
            BackupError.quotaExceeded.userMessage
                == "Your iCloud storage is full. Manage storage in Settings > Apple Account > iCloud, then try again."
        )
    }

    @Test
    func vaultCryptoRejectsCiphertextBoundToAnotherRecord() async throws {
        let crypto = VaultCryptoService()
        let key = await crypto.generateMasterKey()
        let recordID = UUID()
        let generationID = UUID()
        let summary = DecryptedVaultSummary(
            kind: .login,
            title: "Example",
            subtitle: "person@example.com",
            modifiedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let envelope = try await crypto.seal(
            summary,
            recordID: recordID,
            generationID: generationID,
            purpose: .summary,
            keyVersion: 1,
            masterKey: key
        )

        let restored = try await crypto.open(
            DecryptedVaultSummary.self,
            envelope: envelope,
            recordID: recordID,
            generationID: generationID,
            purpose: .summary,
            masterKey: key
        )
        #expect(restored == summary)
        await #expect(throws: VaultCryptoServiceError.self) {
            try await crypto.open(
                DecryptedVaultSummary.self,
                envelope: envelope,
                recordID: UUID(),
                generationID: generationID,
                purpose: .summary,
                masterKey: key
            )
        }
    }

    @Test
    func localVaultCreatesUpdatesAndDeletesEncryptedEntries() async throws {
        let modelContainer = try VaultModelContainerFactory.make(inMemory: true)
        let repository = SwiftDataVaultRepository(modelContainer: modelContainer)
        let assetDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let service = DefaultVaultService(
            repository: repository,
            keyStore: InMemoryVaultKeyStore(),
            crypto: VaultCryptoService(),
            assetStore: try EncryptedAssetStore(rootURL: assetDirectory)
        )
        defer { try? FileManager.default.removeItem(at: assetDirectory) }

        try await service.unlock()
        let id = try await service.createEntry(
            from: .login(LoginDraft(
                title: "Example",
                username: "person@example.com",
                password: "initial-secret",
                website: "https://example.com"
            ))
        )
        let created = try await service.fetchEntry(id: id)
        #expect(created.payload == .login(LoginSecret(
            title: "Example",
            username: "person@example.com",
            password: "initial-secret",
            website: "https://example.com",
            notes: nil
        )))

        try await service.updateEntry(
            id: id,
            with: .login(LoginDraft(
                title: "Example updated",
                username: "person@example.com",
                password: "updated-secret"
            ))
        )
        let updated = try await service.fetchEntry(id: id)
        guard case .login(let login) = updated.payload else {
            Issue.record("Expected a login payload")
            return
        }
        #expect(login.title == "Example updated")
        #expect(login.password == "updated-secret")

        try await service.deleteEntry(id: id)
        await #expect(throws: VaultError.self) {
            try await service.fetchEntry(id: id)
        }
    }
}

actor InMemoryVaultKeyStore: VaultKeyStoring {
    private var keys: [UUID: Data] = [:]

    func saveMasterKey(_ keyData: Data, keyID: UUID) {
        keys[keyID] = keyData
    }

    func loadMasterKey(keyID: UUID, reason: String) throws -> Data {
        guard let key = keys[keyID] else { throw VaultKeyStoreError.itemNotFound }
        return key
    }

    func deleteMasterKey(keyID: UUID, reason: String) {
        keys[keyID] = nil
    }
}

actor BackupServiceStub: BackupServicing {
    private let creationResult: BackupCreationResult?
    private let createError: BackupError?

    init(
        creationResult: BackupCreationResult? = nil,
        createError: BackupError? = nil
    ) {
        self.creationResult = creationResult
        self.createError = createError
    }

    func fetchAvailableBackups() -> [BackupInfo] {
        []
    }

    func createBackup() throws -> BackupCreationResult {
        if let createError {
            throw createError
        }
        guard let creationResult else {
            throw BackupError.uploadFailed
        }
        return creationResult
    }

    func restoreBackup(
        id: UUID,
        using recoveryMethod: BackupRecoveryMethod
    ) {}

    func deleteBackup(id: UUID) {}
}
