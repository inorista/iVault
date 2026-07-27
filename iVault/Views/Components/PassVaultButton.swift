import SwiftUI

struct PassVaultButton: View {
    let title: String
    let variant: PassVaultButtonVariant
    let action: () -> Void
    let isEnabled: Bool

    init(title: String, variant: PassVaultButtonVariant, action: @escaping () -> Void, isEnabled: Bool, minimumHeight: Int = 48) {
        self.title = title
        self.variant = variant
        self.action = action
        self.isEnabled = isEnabled
    }

    @ScaledMetric(relativeTo: .body) private var minimumHeight = 56

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PassVaultTypography.labelLarge)
                .frame(maxWidth: .infinity)
                .frame(minHeight: max(minimumHeight, 44))
                .foregroundStyle(foregroundStyle)
                .background(backgroundStyle)
                .clipShape(.rect(cornerRadius: PassVaultRadius.button))
                .overlay {
                    if variant == .secondary {
                        RoundedRectangle(cornerRadius: PassVaultRadius.button)
                            .stroke(PassVaultColor.border, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private var foregroundStyle: Color {
        switch variant {
        case .primary: PassVaultColor.surface
        case .secondary: PassVaultColor.textPrimary
        }
    }

    private var backgroundStyle: Color {
        switch variant {
        case .primary: PassVaultColor.primary
        case .secondary: PassVaultColor.surface
        }
    }
}

#Preview {
    VStack(spacing: PassVaultSpacing.small) {
        PassVaultButton(title: "Primary Button", variant: .primary, action: {}, isEnabled: true)
        PassVaultButton(title: "Primary Button", variant: .primary, action: {}, isEnabled: true)
    }
    .padding()
    .background(PassVaultColor.background)
}
