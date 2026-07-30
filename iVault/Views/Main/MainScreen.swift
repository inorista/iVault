import SwiftUI

struct MainScreen: View {
    let container: AppContainer
    let onLock: () -> Void
    @State private var selectedTab = PassVaultTab.home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(vaultService: container.vaultService)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(PassVaultTab.home)
            VaultListView(vaultService: container.vaultService)
                .tabItem { Label("Vault", systemImage: "lock.fill") }
                .tag(PassVaultTab.vault)
            PasswordGeneratorView()
                .tabItem { Label("Generator", systemImage: "wand.and.stars") }
                .tag(PassVaultTab.generator)
            SettingsView(backupService: container.backupService, onLock: onLock)
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(PassVaultTab.settings)
        }
        .tint(PassVaultColor.primary)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(PassVaultColor.surface, for: .tabBar)
    }
}
