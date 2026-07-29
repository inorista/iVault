//
//  iVaultApp.swift
//  iVault
//
//  Created by Tu on 26/7/26.
//

import SwiftUI

@main
struct iVaultApp: App {
    @State private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
