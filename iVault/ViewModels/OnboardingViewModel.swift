//
//  OnboardingViewModel.swift
//  iVault
//
//  Created by Tu on 26/7/26.
//

import Foundation

@MainActor
@Observable
class OnboardingViewModel {
    var currentStage = 0
    var onboardingItems = [OnboardingModel]()
    var isLastStage = false

    let userDefaultService: UserDefaultService

    init(userDefaultService: UserDefaultService) {
        self.userDefaultService = userDefaultService
        self.initModel()
    }

    func onBackPressed() {
        guard currentStage > 0 else { return }
        currentStage -= 1
    }

    private func initModel() {
        onboardingItems.removeAll()

        let items = [
            OnboardingModel(
                title: "Sync Everywhere",
                description:
                    "Access your passwords on all your devices. Your data is encrypted and updated in real-time.",
                imagePath: "OnboardingStage2"
            ),
            OnboardingModel(
                title: "Smart Generator",
                description:
                    "Create unbreakable passwords in seconds with our advanced algorithm.",
                imagePath: "OnboardingStage3"
            ),
            OnboardingModel(
                title: "Secure Vault",
                description:
                    "Military-grade encryption for all your passwords. Your data never leaves your device.",
                imagePath: "OnboardingStage4"
            ),
        ]
        onboardingItems.append(contentsOf: items)
    }

    func onNext() {
        if currentStage < onboardingItems.count - 1 {
            currentStage += 1
        }
        isLastStage = currentStage == onboardingItems.count - 1
    }

    func onFinish() {
        userDefaultService.save(true, forKey: UserDefaultKey.onboardingState.keyString)
    }
}
