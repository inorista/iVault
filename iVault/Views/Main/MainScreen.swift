import SwiftUI

struct MainScreen: View {
    @State private var selectedTab = PassVaultTab.home

    var body: some View {
        TabView(selection: $selectedTab) {
            Text("HomeScreen")
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .tabItem {
                    Image(
                        PassVaultTab.home.imagePath(
                            isActive: selectedTab == .home
                        )
                    )
                }
                .tag(PassVaultTab.home)
            Text("Vault")
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .tabItem {
                    Image(
                        PassVaultTab.vault.imagePath(
                            isActive: selectedTab == .vault
                        )
                    )
                }
                .tag(PassVaultTab.vault)

            Text("Generator")
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .tabItem {
                    Image(
                        PassVaultTab.generator.imagePath(
                            isActive: selectedTab == .generator
                        )
                    )
                }
                .tag(PassVaultTab.generator)

            Text("Setting")
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .tabItem {
                    Image(
                        PassVaultTab.settings.imagePath(
                            isActive: selectedTab == .settings
                        )
                    )
                }
                .tag(PassVaultTab.settings)
        }
        .tint(.white)
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .passwordDetail(let UUID):
                Text("\(UUID)")
            }

        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    MainScreen()
}
