import SwiftUI

struct VaultRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    let container: AppContainer
    @State private var sessionViewModel: VaultSessionViewModel
    @State private var isPrivacyShieldVisible = false

    init(container: AppContainer) {
        self.container = container
        _sessionViewModel = State(
            initialValue: VaultSessionViewModel(vaultService: container.vaultService)
        )
    }

    var body: some View {
        ZStack {
            if !sessionViewModel.isReady {
                SplashScreen()
            } else if sessionViewModel.isUnlocked {
                MainScreen(container: container, onLock: lock)
            } else {
                VaultLockView(viewModel: sessionViewModel)
            }
            if isPrivacyShieldVisible {
                VaultScreenBackground()
                    .overlay {
                        VaultIconBadge(systemName: "lock.fill", size: 72)
                    }
                    .transition(.opacity)
            }
        }
        .task { await sessionViewModel.bootstrap() }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else {
                withAnimation(.easeOut(duration: 0.15)) {
                    isPrivacyShieldVisible = false
                }
                return
            }
            isPrivacyShieldVisible = true
            Task { await sessionViewModel.lock() }
        }
    }

    private func lock() {
        Task { await sessionViewModel.lock() }
    }
}
