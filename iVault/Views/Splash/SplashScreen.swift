import SwiftUI

struct SplashScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var markSize = 132.0
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize = 58.0

    var body: some View {
        ZStack {
            PassVaultColor.background
                .ignoresSafeArea()

            VStack(spacing: PassVaultSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(PassVaultColor.background)
                        .frame(width: markSize, height: markSize)
                        .shadow(
                            color: .white.opacity(0.9),
                            radius: 14,
                            x: -10,
                            y: -10
                        )
                        .shadow(
                            color: PassVaultColor.textPrimary.opacity(0.12),
                            radius: 14,
                            x: 10,
                            y: 10
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
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(PassVaultColor.textPrimary)

                    Text("Your privacy, protected.")
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
