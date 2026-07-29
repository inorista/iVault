import Foundation
import SwiftData

/// The composition root constructs concrete services once. View models receive
/// protocols instead, which keeps each MVVM feature independently testable.
@MainActor
final class AppContainer {
    let vaultService: any VaultServicing
    private let backupServiceFactory: @MainActor () -> any BackupServicing
    private var cachedBackupService: (any BackupServicing)?

    var backupService: any BackupServicing {
        if let cachedBackupService { return cachedBackupService }
        let service = backupServiceFactory()
        cachedBackupService = service
        return service
    }

    init(
        vaultService: any VaultServicing,
        backupServiceFactory: @escaping @MainActor () -> any BackupServicing
    ) {
        self.vaultService = vaultService
        self.backupServiceFactory = backupServiceFactory
    }

    static func live() -> AppContainer {
        do {
            let modelContainer = try VaultModelContainerFactory.make()
            let repository = SwiftDataVaultRepository(modelContainer: modelContainer)
            let crypto = VaultCryptoService()
            let vaultService = DefaultVaultService(
                repository: repository,
                keyStore: KeychainVaultKeyStore(),
                crypto: crypto,
                assetStore: try EncryptedAssetStore()
            )
            return AppContainer(
                vaultService: vaultService,
                backupServiceFactory: {
                    CloudKitBackupService(
                        vaultTransfer: vaultService,
                        backupKeyStore: SynchronizedBackupKeyStore(),
                        crypto: crypto
                    )
                }
            )
        } catch {
            fatalError("iVault could not initialize secure storage: \(error)")
        }
    }
}
