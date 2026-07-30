import Foundation
import Observation

@MainActor
@Observable
final class VaultSessionViewModel {
    private let vaultService: any VaultServicing
    private(set) var isReady = false
    private(set) var isUnlocked = false
    private(set) var isUnlocking = false
    var errorMessage: String?

    init(vaultService: any VaultServicing) {
        self.vaultService = vaultService
    }

    func bootstrap() async {
        isUnlocked = await vaultService.isUnlocked
        isReady = true
    }

    func unlock() async {
        guard !isUnlocking else { return }
        isUnlocking = true
        errorMessage = nil
        defer { isUnlocking = false }
        do {
            try await vaultService.unlock()
            isUnlocked = true
        } catch {
            errorMessage = error.userMessage
        }
    }

    func lock() async {
        await vaultService.lock()
        isUnlocked = false
        errorMessage = nil
    }
}
