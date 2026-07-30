import SwiftUI

struct SplashScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var markSize = 132.0
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize = 58.0

    var body: some View {
        ZStack {
            VaultScreenBackground()

            VStack(spacing: PassVaultSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(PassVaultColor.surface)
                        .frame(width: markSize, height: markSize)
                        .shadow(
                            color: PassVaultColor.primary.opacity(0.22),
                            radius: 30,
                            x: 0,
                            y: 16
                        )

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: symbolSize, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(PassVaultColor.primary)
                        .symbolEffect(
                            .pulse,
                            options: .repeating,
                            isActive: !reduceMotion
                        )
                        .accessibilityHidden(true)
                }

                VStack(spacing: PassVaultSpacing.xSmall) {
                    Text("iVault")
                        .font(PassVaultTypography.display)
                        .foregroundStyle(PassVaultColor.textPrimary)

                    Text("Private by design.")
                        .font(PassVaultTypography.bodyLarge)
                        .foregroundStyle(PassVaultColor.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview {
    SplashScreen()
}
