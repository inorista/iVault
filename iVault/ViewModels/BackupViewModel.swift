import Foundation
import Observation

@MainActor
@Observable
final class BackupViewModel {
    private let backupService: any BackupServicing
    private(set) var backups: [BackupInfo] = []
    private(set) var isLoading = false
    private(set) var isWorking = false
    var errorMessage: String?
    var newRecoveryCode: String?

    init(backupService: any BackupServicing) {
        self.backupService = backupService
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            backups = try await backupService.fetchAvailableBackups()
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.userMessage
        }
    }

    func createBackup() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let result = try await backupService.createBackup()
            backups.removeAll { $0.id == result.backup.id }
            backups.insert(result.backup, at: 0)
            newRecoveryCode = result.recoveryCode
        } catch {
            errorMessage = error.userMessage
        }
    }

    func restore(
        backup: BackupInfo,
        recoveryMethod: BackupRecoveryMethod
    ) async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await backupService.restoreBackup(
                id: backup.id,
                using: recoveryMethod
            )
            return true
        } catch {
            errorMessage = error.userMessage
            return false
        }
    }

    func delete(_ backup: BackupInfo) async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await backupService.deleteBackup(id: backup.id)
            backups.removeAll { $0.id == backup.id }
        } catch {
            errorMessage = error.userMessage
        }
    }
}
