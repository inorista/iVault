import Foundation
import Observation

@MainActor
@Observable
final class VaultEditorViewModel {
    private let vaultService: any VaultServicing
    private let entryID: UUID?
    let kind: VaultItemKind
    var title = ""
    var username = ""
    var password = ""
    var website = ""
    var notes = ""
    var noteBody = ""
    var imageData: Data?
    var originalFilename: String?
    var mediaType: String?
    private(set) var isSaving = false
    var errorMessage: String?

    init(
        vaultService: any VaultServicing,
        kind: VaultItemKind,
        entry: VaultEntry? = nil
    ) {
        self.vaultService = vaultService
        entryID = entry?.id
        self.kind = entry?.payload.kind ?? kind
        populate(from: entry?.payload)
    }

    var isEditing: Bool { entryID != nil }

    func save() async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            if let entryID {
                try await vaultService.updateEntry(id: entryID, with: makeDraft())
            } else {
                _ = try await vaultService.createEntry(from: makeDraft())
            }
            return true
        } catch {
            errorMessage = error.userMessage
            return false
        }
    }

    private func populate(from payload: VaultPayload?) {
        guard let payload else { return }
        switch payload {
        case .login(let login):
            title = login.title
            username = login.username
            password = login.password
            website = login.website ?? ""
            notes = login.notes ?? ""
        case .secureNote(let note):
            title = note.title
            noteBody = note.body
        case .image(let image):
            title = image.title
            originalFilename = image.originalFilename
            mediaType = image.mediaType
            notes = image.notes ?? ""
        }
    }

    private func makeDraft() -> VaultItemDraft {
        switch kind {
        case .login:
            .login(LoginDraft(
                title: title,
                username: username,
                password: password,
                website: website,
                notes: notes
            ))
        case .secureNote:
            .secureNote(SecureNoteDraft(title: title, body: noteBody))
        case .image:
            .image(SecureImageDraft(
                title: title,
                imageData: imageData,
                originalFilename: originalFilename,
                mediaType: mediaType,
                notes: notes
            ))
        }
    }
}
