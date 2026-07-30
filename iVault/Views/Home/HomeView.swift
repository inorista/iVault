import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel

    private let columns = [
        GridItem(.flexible(), spacing: PassVaultSpacing.small),
        GridItem(.flexible(), spacing: PassVaultSpacing.small)
    ]

    init(vaultService: any VaultServicing) {
        _viewModel = State(initialValue: HomeViewModel(vaultService: vaultService))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: PassVaultSpacing.large) {
                        hero

                        VaultSectionHeader(
                            title: "Your vault at a glance",
                            subtitle: "A private inventory, always encrypted."
                        )

                        LazyVGrid(columns: columns, spacing: PassVaultSpacing.small) {
                            VaultMetricCard(title: "All items", value: viewModel.itemCount, image: "lock.fill", tint: PassVaultColor.primary)
                            VaultMetricCard(title: "Logins", value: viewModel.loginCount, image: "key.fill", tint: PassVaultColor.accent)
                            VaultMetricCard(title: "Notes", value: viewModel.noteCount, image: "note.text", tint: Color.orange)
                            VaultMetricCard(title: "Images", value: viewModel.imageCount, image: "photo.fill", tint: Color.pink)
                        }

                        safetyCard
                    }
                    .padding(.horizontal, PassVaultSpacing.medium)
                    .padding(.vertical, PassVaultSpacing.large)
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .refreshable { await viewModel.load() }
            }
            .navigationTitle("iVault")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: PassVaultSpacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: PassVaultSpacing.xSmall) {
                    Text("Private by design")
                        .font(PassVaultTypography.display)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("Everything here is encrypted before it reaches storage or iCloud.")
                        .font(PassVaultTypography.bodyLarge)
                        .foregroundStyle(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: PassVaultSpacing.small)
                VaultIconBadge(systemName: "lock.shield.fill", tint: .white.opacity(0.28), size: 56)
            }

            VaultStatusPill(
                title: viewModel.isLoading ? "Updating your vault" : "Encrypted on this device",
                systemName: viewModel.isLoading ? "arrow.triangle.2.circlepath" : "checkmark.shield.fill",
                tint: .white
            )
        }
        .padding(PassVaultSpacing.large)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [PassVaultColor.primary, Color(red: 0.15, green: 0.16, blue: 0.47)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .shadow(color: PassVaultColor.primary.opacity(0.24), radius: 24, x: 0, y: 12)
    }

    private var safetyCard: some View {
        HStack(alignment: .top, spacing: PassVaultSpacing.small) {
            VaultIconBadge(systemName: "eye.slash.fill", tint: PassVaultColor.accent, size: 42)
            VStack(alignment: .leading, spacing: PassVaultSpacing.xxSmall) {
                Text("Automatic privacy shield")
                    .font(PassVaultTypography.labelLarge)
                    .foregroundStyle(PassVaultColor.textPrimary)
                Text("iVault locks itself whenever the app leaves the foreground.")
                    .font(PassVaultTypography.body)
                    .foregroundStyle(PassVaultColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(PassVaultSpacing.medium)
        .vaultSurface()
    }
}

private struct VaultMetricCard: View {
    let title: String
    let value: Int
    let image: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: PassVaultSpacing.small) {
            VaultIconBadge(systemName: image, tint: tint, size: 42)
            Text(value, format: .number)
                .font(PassVaultTypography.heading1)
                .foregroundStyle(PassVaultColor.textPrimary)
                .contentTransition(.numericText())
            Text(title)
                .font(PassVaultTypography.body)
                .foregroundStyle(PassVaultColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PassVaultSpacing.medium)
        .vaultSurface()
        .accessibilityElement(children: .combine)
    }
}
