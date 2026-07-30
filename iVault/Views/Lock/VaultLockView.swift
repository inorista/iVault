import SwiftUI

struct VaultLockView: View {
    let viewModel: VaultSessionViewModel

    var body: some View {
        ZStack {
            VaultScreenBackground()

            VStack(spacing: PassVaultSpacing.xLarge) {
                VStack(spacing: PassVaultSpacing.medium) {
                    VaultIconBadge(systemName: "lock.shield.fill", tint: PassVaultColor.primary, size: 82)
                    VStack(spacing: PassVaultSpacing.xSmall) {
                        Text("Your private space is locked")
                            .font(PassVaultTypography.heading1)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(PassVaultColor.textPrimary)
                        Text("Authenticate to decrypt the information stored only for you.")
                            .font(PassVaultTypography.bodyLarge)
                            .foregroundStyle(PassVaultColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 340)
                    }
                }

                VStack(spacing: PassVaultSpacing.small) {
                    Button {
                        Task { await viewModel.unlock() }
                    } label: {
                        Label(
                            viewModel.isUnlocking ? "Unlocking…" : "Unlock with Face ID",
                            systemImage: "faceid"
                        )
                    }
                    .buttonStyle(VaultActionButtonStyle(tone: .primary))
                    .disabled(viewModel.isUnlocking)
                    .accessibilityIdentifier("unlockVaultButton")

                    VaultStatusPill(
                        title: "Protected by this device",
                        systemName: "checkmark.shield.fill"
                    )
                }

                if let errorMessage = viewModel.errorMessage {
                    VaultInlineMessage(
                        message: errorMessage,
                        systemName: "exclamationmark.triangle.fill",
                        tint: PassVaultColor.danger
                    )
                }
            }
            .padding(PassVaultSpacing.large)
            .frame(maxWidth: 420)
            .vaultSurface(cornerRadius: 32, elevated: true)
            .padding(PassVaultSpacing.medium)
        }
    }
}
