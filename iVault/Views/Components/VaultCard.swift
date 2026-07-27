import SwiftUI

struct VaultCard: View {
    let item: VaultItem
    let onReveal: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: PassVaultSpacing.small) {
            Image(systemName: item.systemImage)
                .font(.title3)
                .foregroundStyle(PassVaultColor.surface)
                .frame(width: 40, height: 40)
                .background(PassVaultColor.textPrimary)
                .clipShape(.rect(cornerRadius: PassVaultRadius.input))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(PassVaultTypography.labelLarge)
                    .foregroundStyle(PassVaultColor.textPrimary)

                Text(item.subtitle)
                    .font(PassVaultTypography.body)
                    .foregroundStyle(PassVaultColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button("Reveal password", systemImage: "eye", action: onReveal)
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)

            Button("Share vault item", systemImage: "square.and.arrow.up", action: onShare)
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
        }
        .foregroundStyle(PassVaultColor.textSecondary)
        .padding(PassVaultSpacing.small)
        .background(PassVaultColor.surface)
        .clipShape(.rect(cornerRadius: PassVaultRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: PassVaultRadius.card)
                .stroke(PassVaultColor.border, lineWidth: 1)
        }
        .passVaultSoftShadow()
    }
}

#Preview {
    VaultCard(
        item: VaultItem(
            id: "google",
            title: "Google Account",
            subtitle: "user@gmail.com",
            systemImage: "lock.shield.fill"
        ),
        onReveal: {},
        onShare: {}
    )
    .padding()
    .background(PassVaultColor.background)
}
