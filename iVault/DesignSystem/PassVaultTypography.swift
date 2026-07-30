import SwiftUI

enum PassVaultTypography {
    // Cabinet Grotesk is the intended display direction; the rounded system face is
    // the dynamic-type-safe on-device fallback until a licensed custom font is added.
    static let display = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let heading1 = Font.system(.title, design: .rounded, weight: .bold)
    static let heading2 = Font.system(.title2, design: .rounded, weight: .bold)
    static let heading3 = Font.system(.title3, design: .rounded, weight: .semibold)
    static let bodyLarge = Font.system(.body, design: .rounded)
    static let body = Font.system(.subheadline, design: .rounded)
    static let labelLarge = Font.system(.body, design: .rounded, weight: .semibold)
    static let label = Font.system(.subheadline, design: .rounded, weight: .semibold)
    static let caption = Font.system(.caption, design: .rounded, weight: .medium)
    static let mono = Font.system(.body, design: .monospaced, weight: .medium)
}
