import SwiftUI

struct SettingsView: View {
    let backupService: any BackupServicing
    let onLock: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                VaultScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: PassVaultSpacing.large) {
                        header

                        VaultSectionHeader(title: "Data protection")
                        NavigationLink {
                            BackupView(backupService: backupService)
                        } label: {
                            VaultSettingsCard(
                                title: "Backup & restore",
                                subtitle: "Encrypted snapshots in your private iCloud database.",
                                systemName: "icloud.and.arrow.up.fill",
                                tint: PassVaultColor.primary
                            )
                        }
                        .buttonStyle(.plain)

                        VaultSectionHeader(title: "App security")
                        Button(action: onLock) {
                            VaultSettingsCard(
                                title: "Lock iVault now",
                                subtitle: "Require Face ID before private data can be seen again.",
                                systemName: "lock.fill",
                                tint: PassVaultColor.danger,
                                showsChevron: false
                            )
                        }
                        .buttonStyle(.plain)

                        encryptionNote
                    }
                    .padding(.horizontal, PassVaultSpacing.medium)
                    .padding(.vertical, PassVaultSpacing.large)
                    .frame(maxWidth: 620, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: PassVaultSpacing.medium) {
            VaultIconBadge(systemName: "gearshape.fill", tint: PassVaultColor.primary, size: 60)
            VStack(alignment: .leading, spacing: PassVaultSpacing.xxSmall) {
                Text("Security is the default")
                    .font(PassVaultTypography.heading2)
                    .foregroundStyle(PassVaultColor.textPrimary)
                Text("Control how this device protects your vault.")
                    .font(PassVaultTypography.body)
                    .foregroundStyle(PassVaultColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var encryptionNote: some View {
        HStack(alignment: .top, spacing: PassVaultSpacing.small) {
            VaultIconBadge(systemName: "checkmark.shield.fill", tint: PassVaultColor.accent, size: 42)
            VStack(alignment: .leading, spacing: PassVaultSpacing.xxSmall) {
                Text("Built for private information")
                    .font(PassVaultTypography.labelLarge)
                    .foregroundStyle(PassVaultColor.textPrimary)
                Text("Entries use AES-GCM encryption. Your master key remains in the Keychain protected by this device.")
                    .font(PassVaultTypography.body)
                    .foregroundStyle(PassVaultColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(PassVaultSpacing.medium)
        .vaultSurface()
    }
}

private struct VaultSettingsCard: View {
    let title: String
    let subtitle: String
    let systemName: String
    let tint: Color
    var showsChevron = true

    var body: some View {
        HStack(spacing: PassVaultSpacing.small) {
            VaultIconBadge(systemName: systemName, tint: tint, size: 48)
            VStack(alignment: .leading, spacing: PassVaultSpacing.xxSmall) {
                Text(title)
                    .font(PassVaultTypography.labelLarge)
                    .foregroundStyle(PassVaultColor.textPrimary)
                Text(subtitle)
                    .font(PassVaultTypography.body)
                    .foregroundStyle(PassVaultColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: PassVaultSpacing.xSmall)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PassVaultColor.textSecondary)
            }
        }
        .padding(PassVaultSpacing.medium)
        .vaultSurface()
    }
}
