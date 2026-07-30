import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum PassVaultColor {
    static let primary = Color(red: 0.24, green: 0.30, blue: 0.92)
    static let primaryPressed = Color(red: 0.17, green: 0.22, blue: 0.72)
    static let accent = Color(red: 0.07, green: 0.64, blue: 0.62)
    static let danger = Color(red: 0.84, green: 0.20, blue: 0.29)
    static let success = Color(red: 0.08, green: 0.55, blue: 0.37)

    #if canImport(UIKit)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let elevatedSurface = Color(uiColor: .tertiarySystemGroupedBackground)
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let border = Color(uiColor: .separator)
    #else
    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let elevatedSurface = Color(.tertiarySystemGroupedBackground)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let border = Color.secondary.opacity(0.24)
    #endif
}
