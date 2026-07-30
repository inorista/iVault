import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct PasswordGeneratorView: View {
    @State private var length = 20.0
    @State private var includesSymbols = true
    @State private var includesNumbers = true
    @State private var generatedPassword = ""
    @State private var didCopy = false

    var body: some View {
        NavigationStack {
            ZStack {
                VaultScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: PassVaultSpacing.large) {
                        header
                        passwordCard
                        controlsCard
                        PassVaultButton(
                            title: "Generate a new password",
                            systemImage: "arrow.triangle.2.circlepath",
                            variant: .primary,
                            action: generate,
                            isEnabled: true
                        )
                    }
                    .padding(.horizontal, PassVaultSpacing.medium)
                    .padding(.vertical, PassVaultSpacing.large)
                    .frame(maxWidth: 620, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Generator")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            guard generatedPassword.isEmpty else { return }
            generate()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: PassVaultSpacing.xSmall) {
            Text("Passwords made to stay private")
                .font(PassVaultTypography.heading1)
                .foregroundStyle(PassVaultColor.textPrimary)
                .frame(maxWidth: 520, alignment: .leading)
            Text("Create a unique password, then save it directly in your encrypted vault.")
                .font(PassVaultTypography.bodyLarge)
                .foregroundStyle(PassVaultColor.textSecondary)
                .frame(maxWidth: 500, alignment: .leading)
        }
    }

    private var passwordCard: some View {
        VStack(alignment: .leading, spacing: PassVaultSpacing.medium) {
            HStack {
                VaultStatusPill(title: strengthTitle, systemName: "shield.checkered", tint: strengthTint)
                Spacer()
                Button(action: copyPassword) {
                    Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .tint(PassVaultColor.primary)
                .disabled(generatedPassword.isEmpty)
            }

            Text(generatedPassword.isEmpty ? "Generate a password" : generatedPassword)
                .font(.system(.title3, design: .monospaced, weight: .semibold))
                .foregroundStyle(PassVaultColor.textPrimary)
                .textSelection(.enabled)
                .privacySensitive()
                .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                .padding(PassVaultSpacing.medium)
                .background(PassVaultColor.background, in: RoundedRectangle(cornerRadius: PassVaultRadius.input, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PassVaultRadius.input, style: .continuous)
                        .stroke(PassVaultColor.border.opacity(0.55), lineWidth: 0.8)
                }
        }
        .padding(PassVaultSpacing.medium)
        .vaultSurface(elevated: true)
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: PassVaultSpacing.medium) {
            VaultSectionHeader(title: "Tune your password")

            VStack(alignment: .leading, spacing: PassVaultSpacing.xSmall) {
                HStack {
                    Text("Length")
                        .font(PassVaultTypography.labelLarge)
                        .foregroundStyle(PassVaultColor.textPrimary)
                    Spacer()
                    Text("\(Int(length)) characters")
                        .font(PassVaultTypography.caption)
                        .foregroundStyle(PassVaultColor.primary)
                }
                Slider(value: $length, in: 12 ... 64, step: 1)
                    .tint(PassVaultColor.primary)
            }

            Divider()

            Toggle(isOn: $includesNumbers) {
                Label("Include numbers", systemImage: "number")
            }
            .tint(PassVaultColor.primary)

            Toggle(isOn: $includesSymbols) {
                Label("Include symbols", systemImage: "textformat.abc")
            }
            .tint(PassVaultColor.primary)
        }
        .font(PassVaultTypography.body)
        .padding(PassVaultSpacing.medium)
        .vaultSurface()
    }

    private var strengthTitle: String {
        switch Int(length) + (includesNumbers ? 7 : 0) + (includesSymbols ? 9 : 0) {
        case ..<24: "Good"
        case ..<34: "Strong"
        default: "Very strong"
        }
    }

    private var strengthTint: Color {
        switch strengthTitle {
        case "Good": .orange
        case "Strong": PassVaultColor.accent
        default: PassVaultColor.success
        }
    }

    private func generate() {
        generatedPassword = PasswordGenerator.generate(
            length: Int(length),
            includesNumbers: includesNumbers,
            includesSymbols: includesSymbols
        )
        didCopy = false
    }

    private func copyPassword() {
        #if canImport(UIKit)
        UIPasteboard.general.string = generatedPassword
        #endif
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            didCopy = false
        }
    }
}

nonisolated enum PasswordGenerator {
    static func generate(
        length: Int,
        includesNumbers: Bool,
        includesSymbols: Bool
    ) -> String {
        var alphabet = Array("abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ")
        if includesNumbers { alphabet += Array("23456789") }
        if includesSymbols { alphabet += Array("!@#$%^&*_-+=") }
        var generator = SystemRandomNumberGenerator()
        return String((0 ..< max(length, 1)).compactMap { _ in
            alphabet.randomElement(using: &generator)
        })
    }
}
