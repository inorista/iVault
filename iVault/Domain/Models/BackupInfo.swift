import Foundation

/// The lifecycle state of an immutable backup snapshot.
nonisolated enum BackupState: String, Codable, Equatable, Sendable {
    case uploading
    case complete
}

/// Non-secret metadata used to display and select an iCloud backup.
nonisolated struct BackupInfo: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let completedAt: Date?
    let state: BackupState
    let recordCount: Int
    let assetCount: Int
    let encryptedByteCount: Int64
    let formatVersion: Int
    let appVersion: String

    var isRestorable: Bool {
        state == .complete
    }
}

/// A recovery code is returned once and never persisted by iVault.
nonisolated struct BackupCreationResult: Equatable, Sendable {
    let backup: BackupInfo
    let recoveryCode: String
}
