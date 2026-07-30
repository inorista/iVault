enum PassVaultTab: String, CaseIterable, Identifiable {
    case home
    case vault
    case generator
    case settings

    var id: Self { self }

    func imagePath(isActive: Bool) -> String {
        return switch self {
        case .home:
            isActive ? "HomeActiveIcon" : "HomeInactiveIcon"
        case .vault:
            isActive ? "VaultActiveIcon" : "VaultInactiveIcon"
        case .generator:
            isActive ? "GeneratorActiveIcon" : "GeneratorInactiveIcon"
        case .settings:
            isActive ? "SettingActiveIcon" : "SettingInactiveIcon"
        }
    }
}
