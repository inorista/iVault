import Foundation

/// Ciphertext-only material transferred between vault and backup layers.
nonisolated struct VaultBackupSnapshot: Codable, Equatable, Sendable {
    let sourceGenerationID: UUID
    let masterKeyData: Data
    let records: [StoredVaultRecord]
    let assets: [VaultBackupAsset]
}

nonisolated struct VaultBackupAsset: Codable, Equatable, Sendable {
    let metadata: StoredVaultAsset
    let ciphertext: Data
}

nonisolated protocol VaultBackupDataTransferring: Sendable {
    func exportBackupSnapshot() async throws -> VaultBackupSnapshot
    func replaceVault(with snapshot: VaultBackupSnapshot) async throws
}
