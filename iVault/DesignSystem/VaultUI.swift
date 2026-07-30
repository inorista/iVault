import SwiftUI

struct VaultScreenBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            PassVaultColor.background

            Circle()
                .fill(PassVaultColor.primary.opacity(colorScheme == .dark ? 0.20 : 0.12))
                .frame(width: 340, height: 340)
                .blur(radius: 70)
                .offset(x: -150, y: -290)

            Circle()
                .fill(PassVaultColor.accent.opacity(colorScheme == .dark ? 0.14 : 0.09))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 170, y: 330)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct VaultSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isElevated: Bool

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isElevated ? PassVaultColor.elevatedSurface : PassVaultColor.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(PassVaultColor.border.opacity(0.45), lineWidth: 0.8)
                    }
            }
            .shadow(
                color: PassVaultColor.textPrimary.opacity(isElevated ? 0.10 : 0.055),
                radius: isElevated ? 20 : 12,
                x: 0,
                y: isElevated ? 10 : 5
            )
    }
}

extension View {
    func vaultSurface(
        cornerRadius: CGFloat = PassVaultRadius.card,
        elevated: Bool = false
    ) -> some View {
        modifier(VaultSurfaceModifier(cornerRadius: cornerRadius, isElevated: elevated))
    }
}

struct VaultIconBadge: View {
    let systemName: String
    var tint: Color = PassVaultColor.primary
    var size: CGFloat = 48

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.62)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: tint.opacity(0.28), radius: 12, x: 0, y: 7)
            .accessibilityHidden(true)
    }
}

struct VaultSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: PassVaultSpacing.xxSmall) {
            Text(title)
                .font(PassVaultTypography.heading3)
                .foregroundStyle(PassVaultColor.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(PassVaultTypography.body)
                    .foregroundStyle(PassVaultColor.textSecondary)
            }
        }
    }
}

struct VaultStatusPill: View {
    let title: String
    let systemName: String
    var tint: Color = PassVaultColor.accent

    var body: some View {
        Label(title, systemImage: systemName)
            .font(PassVaultTypography.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct VaultActionButtonStyle: ButtonStyle {
    enum Tone {
        case primary
        case secondary
        case destructive
    }

    let tone: Tone
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PassVaultTypography.labelLarge)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: PassVaultRadius.button, style: .continuous))
            .overlay {
                if tone == .secondary {
                    RoundedRectangle(cornerRadius: PassVaultRadius.button, style: .continuous)
                        .stroke(PassVaultColor.border.opacity(0.7), lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch tone {
        case .primary, .destructive:
            .white
        case .secondary:
            PassVaultColor.textPrimary
        }
    }

    private var background: Color {
        switch tone {
        case .primary:
            PassVaultColor.primary
        case .secondary:
            PassVaultColor.surface
        case .destructive:
            PassVaultColor.danger
        }
    }
}

struct VaultIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundStyle(PassVaultColor.textPrimary)
                .frame(width: 44, height: 44)
                .background(PassVaultColor.surface, in: Circle())
                .overlay {
                    Circle()
                        .stroke(PassVaultColor.border.opacity(0.45), lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct VaultEmptyState: View {
    let systemName: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: PassVaultSpacing.medium) {
            VaultIconBadge(systemName: systemName, tint: PassVaultColor.accent, size: 64)
            VStack(spacing: PassVaultSpacing.xSmall) {
                Text(title)
                    .font(PassVaultTypography.heading2)
                    .foregroundStyle(PassVaultColor.textPrimary)
                Text(message)
                    .font(PassVaultTypography.body)
                    .foregroundStyle(PassVaultColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(PassVaultSpacing.xLarge)
        .vaultSurface(elevated: true)
    }
}

struct VaultInlineMessage: View {
    let message: String
    let systemName: String
    var tint: Color = PassVaultColor.accent

    var body: some View {
        Label(message, systemImage: systemName)
            .font(PassVaultTypography.body)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PassVaultSpacing.small)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: PassVaultRadius.input, style: .continuous))
    }
}
