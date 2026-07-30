//
//  AppCoordinator.swift
//  iVault
//
//  Created by Tu on 27/7/26.
//

import Foundation
import Observation

nonisolated enum VaultRoute: Hashable, Sendable {
    case detail(UUID)
}

@MainActor
@Observable
final class VaultRouter {
    var path: [VaultRoute] = []

    func showDetail(id: UUID) {
        path.append(.detail(id))
    }

    func popToRoot() {
        path = []
    }
}
