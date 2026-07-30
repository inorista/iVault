import Foundation

/// A decrypted vault entry available only while the vault is unlocked.
nonisolated struct VaultEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let modifiedAt: Date
    let payload: VaultPayload
}
