//
//  AppCoordinator.swift
//  iVault
//
//  Created by Tu on 27/7/26.
//

import Foundation

enum AppRoute: Hashable {
    case passwordDetail(id: UUID)
}

enum AppTab: String, CaseIterable {
    case home
    case vault
    case generator
    case setting

    func imagePath(isActive: Bool) -> String {
        switch self {
        case .home:
            return isActive ? "HomeActiveIcon" : "HomeInactiveIcon"
        case .vault:
            return isActive ? "VaultActiveIcon" : "VaultInactiveIcon"
        case .generator:
            return isActive ? "GeneratorActiveIcon" : "GeneratorInactiveIcon"
        case .setting:
            return isActive ? "SettingActiveIcon" : "SettingInactiveIcon"
        }
    }
}
