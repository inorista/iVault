//
//  MainViewModel.swift
//  iVault
//
//  Created by Tu on 27/7/26.
//

import Foundation

@MainActor
@Observable class MainViewModel{
    var selectedTab: PassVaultTab = PassVaultTab.home
}
