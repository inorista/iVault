import SwiftUI

struct PassVaultSoftShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(
                color: PassVaultColor.textPrimary.opacity(0.08),
                radius: 18,
                x: 0,
                y: 8
            )
    }
}

extension View {
    func passVaultSoftShadow() -> some View {
        modifier(PassVaultSoftShadow())
    }
}
