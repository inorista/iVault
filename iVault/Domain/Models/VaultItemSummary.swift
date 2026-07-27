import Foundation

/// Decrypted display information for a vault list row.
struct VaultItemSummary: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: VaultItemKind
    let title: String
    let subtitle: String?
    let modifiedAt: Date
}
