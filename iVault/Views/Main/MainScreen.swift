import SwiftUI

struct MainScreen: View {
    @State private var viewModel = MainViewModel()

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            Text("HomeScreen")
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .tabItem {
                    Image(
                        AppTab.home.imagePath(isActive: viewModel.selectedTab == .home)
                    )
                }
                .tag(AppTab.home)

            Text("Vault")
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .tabItem {
                    Image(
                        AppTab.vault.imagePath(isActive: viewModel.selectedTab == .vault)
                    )
                }
                .tag(AppTab.vault)

            Text("Generator")
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .tabItem {
                    Image(
                        AppTab.generator.imagePath(isActive: viewModel.selectedTab == .generator)
                    )
                }
                .tag(AppTab.generator)

            Text("Setting")
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .tabItem {
                    Image(
                        AppTab.setting.imagePath(isActive: viewModel.selectedTab == .settings)
                    )
                }
                .tag(AppTab.setting)
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
