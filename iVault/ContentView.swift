//
//  ContentView.swift
//  iVault
//
//  Created by Tu on 26/7/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(UserDefaultKey.onboardingState.keyString)
    private var hasCompletedOnboarding = false

    @State private var isShowingSplash = true
    let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    var body: some View {
        ZStack {
            if isShowingSplash {
                SplashScreen()
                    .transition(.opacity)
            } else if hasCompletedOnboarding {
                VaultRootView(container: container)
                    .transition(.opacity)
            } else {
                OnboardingView(userDefaultService: UserDefaultService.shared)
                    .transition(.opacity)
            }
        }
        .animation(rootTransition, value: isShowingSplash)
        .animation(rootTransition, value: hasCompletedOnboarding)
        .task {
            try? await Task.sleep(for: .seconds(1.25))
            guard !Task.isCancelled else { return }
            isShowingSplash = false
        }
    }

    private var rootTransition: Animation {
        reduceMotion
            ? .easeOut(duration: 0.15)
            : .smooth(duration: 0.4)
    }
}
