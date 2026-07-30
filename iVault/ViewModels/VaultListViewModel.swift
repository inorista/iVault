import Foundation
import Observation

@MainActor
@Observable
final class VaultListViewModel {
    let vaultService: any VaultServicing
    private(set) var items: [VaultItemSummary] = []
    private(set) var isLoading = false
    private(set) var isDeleting = false
    var searchText = ""
    var errorMessage: String?

    init(vaultService: any VaultServicing) {
        self.vaultService = vaultService
    }

    var filteredItems: [VaultItemSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || ($0.subtitle?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await vaultService.fetchItemSummaries()
        } catch {
            errorMessage = error.userMessage
        }
    }

    func delete(_ item: VaultItemSummary) async {
        guard !isDeleting else { return }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            try await vaultService.deleteEntry(id: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.userMessage
        }
    }
}
