import Foundation

/// A supported category of private data in the vault.
nonisolated enum VaultItemKind: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case login
    case secureNote
    case image

    var id: Self { self }

    var title: String {
        switch self {
        case .login: "Login"
        case .secureNote: "Secure Note"
        case .image: "Private Image"
        }
    }

    var systemImage: String {
        switch self {
        case .login: "key.fill"
        case .secureNote: "note.text"
        case .image: "photo.fill"
        }
    }
}
