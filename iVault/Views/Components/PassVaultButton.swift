import SwiftUI

struct PassVaultButton: View {
    let title: String
    let systemImage: String?
    let variant: PassVaultButtonVariant
    let action: () -> Void
    let isEnabled: Bool

    init(
        title: String,
        systemImage: String? = nil,
        variant: PassVaultButtonVariant,
        action: @escaping () -> Void,
        isEnabled: Bool
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.action = action
        self.isEnabled = isEnabled
    }

    var body: some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .buttonStyle(VaultActionButtonStyle(tone: tone))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private var tone: VaultActionButtonStyle.Tone {
        switch variant {
        case .primary: .primary
        case .secondary: .secondary
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
