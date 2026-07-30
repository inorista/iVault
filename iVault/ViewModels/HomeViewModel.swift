//
//  HomeViewModel.swift
//  iVault
//
//  Created by Tu on 27/7/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    private let vaultService: any VaultServicing
    private(set) var itemCount = 0
    private(set) var loginCount = 0
    private(set) var noteCount = 0
    private(set) var imageCount = 0
    private(set) var isLoading = false

    init(vaultService: any VaultServicing) {
        self.vaultService = vaultService
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        guard let items = try? await vaultService.fetchItemSummaries() else { return }
        itemCount = items.count
        loginCount = items.filter { $0.kind == .login }.count
        noteCount = items.filter { $0.kind == .secureNote }.count
        imageCount = items.filter { $0.kind == .image }.count
    }
}
