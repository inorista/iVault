import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct VaultDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: VaultDetailViewModel
    @State private var entryBeingEdited: VaultEntry?
    @State private var isShowingDeleteConfirmation = false
    let onChanged: () -> Void
    let onDeleted: () -> Void

    init(
        vaultService: any VaultServicing,
        entryID: UUID,
        onChanged: @escaping () -> Void,
        onDeleted: @escaping () -> Void
    ) {
        _viewModel = State(
            initialValue: VaultDetailViewModel(vaultService: vaultService, entryID: entryID)
        )
        self.onChanged = onChanged
        self.onDeleted = onDeleted
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.entry == nil {
                ZStack {
                    VaultScreenBackground()
                    ProgressView("Decrypting item…")
                        .padding(PassVaultSpacing.large)
                        .vaultSurface()
                }
            } else if let entry = viewModel.entry {
                detail(for: entry)
            } else {
                ZStack {
                    VaultScreenBackground()
                    VaultEmptyState(
                        systemName: "exclamationmark.triangle",
                        title: "Item unavailable",
                        message: viewModel.errorMessage ?? "This item may have been deleted."
                    )
                    .padding(PassVaultSpacing.medium)
                }
            }
        }
        .navigationTitle(viewModel.entry.map(title) ?? "Vault item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let entry = viewModel.entry {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit", systemImage: "pencil") { entryBeingEdited = entry }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            isShowingDeleteConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
        }
        .task { await viewModel.load() }
        .sheet(item: $entryBeingEdited) { entry in
            VaultEditorView(vaultService: viewModel.vaultService, kind: entry.payload.kind, entry: entry) {
                onChanged()
                Task { await viewModel.load() }
            }
        }
        .confirmationDialog(
            "Delete this item?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.delete() {
                        onDeleted()
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This removes the encrypted item and image file from this device.")
        }
        .alert("Vault error", isPresented: errorBinding) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func detail(for entry: VaultEntry) -> some View {
        ZStack {
            VaultScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: PassVaultSpacing.large) {
                    detailHeader(for: entry)

                    switch entry.payload {
                    case .login(let login):
                        loginDetail(login)
                    case .secureNote(let note):
                        noteDetail(note)
                    case .image(let image):
                        imageDetail(image)
                    }

                    metadata(for: entry)
                }
                .padding(.horizontal, PassVaultSpacing.medium)
                .padding(.vertical, PassVaultSpacing.large)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func detailHeader(for entry: VaultEntry) -> some View {
        HStack(alignment: .center, spacing: PassVaultSpacing.medium) {
            VaultIconBadge(systemName: entry.payload.kind.systemImage, tint: tint(for: entry.payload.kind), size: 64)
            VStack(alignment: .leading, spacing: PassVaultSpacing.xxSmall) {
                Text(title(for: entry))
                    .font(PassVaultTypography.heading1)
                    .foregroundStyle(PassVaultColor.textPrimary)
                    .lineLimit(2)
                VaultStatusPill(title: entry.payload.kind.title, systemName: entry.payload.kind.systemImage, tint: tint(for: entry.payload.kind))
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func loginDetail(_ login: LoginSecret) -> some View {
        VStack(alignment: .leading, spacing: PassVaultSpacing.small) {
            VaultSectionHeader(title: "Credentials")
            VaultSensitiveValueRow(title: "Username", value: login.username, systemName: "person.fill", isSensitive: false)
            VaultSensitiveValueRow(
                title: "Password",
                value: login.password,
                systemName: "key.fill",
                isSensitive: !viewModel.isPasswordVisible,
                actionTitle: viewModel.isPasswordVisible ? "Hide" : "Reveal"
            ) {
                viewModel.isPasswordVisible.toggle()
            }
            if let website = login.website, !website.isEmpty {
                VaultSensitiveValueRow(title: "Website", value: website, systemName: "globe", isSensitive: false)
            }
            if let notes = login.notes, !notes.isEmpty {
                VaultBodyCard(title: "Notes", text: notes, systemName: "note.text")
            }
        }
    }

    private func noteDetail(_ note: SecureNote) -> some View {
        VaultBodyCard(title: "Secure note", text: note.body, systemName: "note.text")
    }

    @ViewBuilder
    private func imageDetail(_ image: SecureImage) -> some View {
        VStack(alignment: .leading, spacing: PassVaultSpacing.small) {
            VaultSectionHeader(title: "Private image")
            VStack(alignment: .leading, spacing: PassVaultSpacing.small) {
                encryptedImageView
                HStack {
                    Label(image.byteCount.formatted(.byteCount(style: .file)), systemImage: "internaldrive")
                    Spacer()
                    Text("Decrypted only while open")
                }
                .font(PassVaultTypography.caption)
                .foregroundStyle(PassVaultColor.textSecondary)
            }
            .padding(PassVaultSpacing.medium)
            .vaultSurface()

            if let notes = image.notes, !notes.isEmpty {
                VaultBodyCard(title: "Notes", text: notes, systemName: "note.text")
            }
        }
    }

    private func metadata(for entry: VaultEntry) -> some View {
        VStack(alignment: .leading, spacing: PassVaultSpacing.small) {
            VaultSectionHeader(title: "Details")
            VStack(spacing: 0) {
                VaultMetadataRow(title: "Created", value: entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                Divider().padding(.leading, 16)
                VaultMetadataRow(title: "Last modified", value: entry.modifiedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .vaultSurface()
        }
    }

    @ViewBuilder
    private var encryptedImageView: some View {
        #if canImport(UIKit)
        if let data = viewModel.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 420)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: PassVaultRadius.input, style: .continuous))
                .accessibilityLabel("Decrypted private image")
        } else {
            ProgressView("Decrypting image…")
                .frame(maxWidth: .infinity, minHeight: 180)
        }
        #else
        Text(viewModel.imageData == nil ? "Decrypting image…" : "Private image decrypted")
        #endif
    }

    private func title(for entry: VaultEntry) -> String {
        switch entry.payload {
        case .login(let login): login.title
        case .secureNote(let note): note.title
        case .image(let image): image.title
        }
    }

    private func tint(for kind: VaultItemKind) -> Color {
        switch kind {
        case .login: PassVaultColor.primary
        case .secureNote: PassVaultColor.accent
        case .image: .pink
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

private struct VaultSensitiveValueRow: View {
    let title: String
    let value: String
    let systemName: String
    let isSensitive: Bool
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @State private var didCopy = false

    var body: some View {
        HStack(spacing: PassVaultSpacing.small) {
            VaultIconBadge(systemName: systemName, tint: PassVaultColor.primary, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(PassVaultTypography.caption)
                    .foregroundStyle(PassVaultColor.textSecondary)
                Text(isSensitive ? String(repeating: "•", count: min(max(value.count, 10), 18)) : value)
                    .font(isSensitive ? PassVaultTypography.mono : PassVaultTypography.labelLarge)
                    .foregroundStyle(PassVaultColor.textPrimary)
                    .lineLimit(1)
                    .privacySensitive(isSensitive)
            }
            Spacer(minLength: 0)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .tint(PassVaultColor.primary)
            }
            Button(action: copy) {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .tint(PassVaultColor.primary)
            .accessibilityLabel("Copy \(title)")
        }
        .padding(PassVaultSpacing.medium)
        .vaultSurface()
    }

    private func copy() {
        #if canImport(UIKit)
        UIPasteboard.general.string = value
        #endif
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            didCopy = false
        }
    }
}

private struct VaultBodyCard: View {
    let title: String
    let text: String
    let systemName: String

    var body: some View {
        VStack(alignment: .leading, spacing: PassVaultSpacing.small) {
            Label(title, systemImage: systemName)
                .font(PassVaultTypography.labelLarge)
                .foregroundStyle(PassVaultColor.textPrimary)
            Text(text)
                .font(PassVaultTypography.bodyLarge)
                .foregroundStyle(PassVaultColor.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PassVaultSpacing.medium)
        .vaultSurface()
    }
}

private struct VaultMetadataRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(PassVaultTypography.body)
                .foregroundStyle(PassVaultColor.textSecondary)
            Spacer()
            Text(value)
                .font(PassVaultTypography.caption)
                .foregroundStyle(PassVaultColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(PassVaultSpacing.medium)
    }
}
