import Foundation

/// A supported category of private data in the vault.
enum VaultItemKind: String, CaseIterable, Codable, Equatable, Sendable {
    case login
    case secureNote
    case image
}
