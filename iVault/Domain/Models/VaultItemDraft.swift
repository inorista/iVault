/// Editable values for one new or existing vault entry.
///
/// Drafts are presentation inputs and must never be persisted as plaintext.
enum VaultItemDraft: Equatable, Sendable {
    case login(LoginDraft)
    case secureNote(SecureNoteDraft)
    case image(SecureImageDraft)

    var kind: VaultItemKind {
        switch self {
        case .login:
            .login
        case .secureNote:
            .secureNote
        case .image:
            .image
        }
    }
}
