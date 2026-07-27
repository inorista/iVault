//
//  Enums.swift
//  iVault
//
//  Created by Tu on 27/7/26.
//

import Foundation

enum UserDefaultKey {
    case onboardingState

    var keyString: String {
        switch self {
        case .onboardingState:
            return "OnboardingState"
        }
    }
}
