import Foundation
import Observation

@MainActor
@Observable
final class VaultDetailViewModel {
    let vaultService: any VaultServicing
    let entryID: UUID
    private(set) var entry: VaultEntry?
    private(set) var imageData: Data?
    private(set) var isLoading = false
    private(set) var isDeleting = false
    var isPasswordVisible = false
    var errorMessage: String?

    init(vaultService: any VaultServicing, entryID: UUID) {
        self.vaultService = vaultService
        self.entryID = entryID
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let entry = try await vaultService.fetchEntry(id: entryID)
            self.entry = entry
            if case .image(let image) = entry.payload {
                imageData = try await vaultService.fetchImageData(assetID: image.assetID)
            } else {
                imageData = nil
            }
        } catch {
            errorMessage = error.userMessage
        }
    }

    func delete() async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            try await vaultService.deleteEntry(id: entryID)
            return true
        } catch {
            errorMessage = error.userMessage
            return false
        }
    }
}
