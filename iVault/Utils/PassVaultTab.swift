enum PassVaultTab: String, CaseIterable, Identifiable {
    case home
    case vault
    case generator
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Home"
        case .vault: "Vault"
        case .generator: "Generator"
        case .settings: "Settings"
        }
    }
}
