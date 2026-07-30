import PhotosUI
import SwiftUI

struct VaultEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: VaultEditorViewModel
    @State private var photoPickerItem: PhotosPickerItem?
    let onSaved: () -> Void

    init(
        vaultService: any VaultServicing,
        kind: VaultItemKind,
        entry: VaultEntry? = nil,
        onSaved: @escaping () -> Void
    ) {
        _viewModel = State(
            initialValue: VaultEditorViewModel(vaultService: vaultService, kind: kind, entry: entry)
        )
        self.onSaved = onSaved
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ZStack {
                VaultScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: PassVaultSpacing.large) {
                        header

                        switch viewModel.kind {
                        case .login:
                            loginFields(viewModel: viewModel)
                        case .secureNote:
                            noteFields(viewModel: viewModel)
                        case .image:
                            imageFields(viewModel: viewModel)
                        }
                    }
                    .padding(.horizontal, PassVaultSpacing.medium)
                    .padding(.top, PassVaultSpacing.large)
                    .padding(.bottom, PassVaultSpacing.hero)
                    .frame(maxWidth: 680, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: PassVaultSpacing.xSmall) {
                        if let errorMessage = viewModel.errorMessage {
                            VaultInlineMessage(
                                message: errorMessage,
                                systemName: "exclamationmark.triangle.fill",
                                tint: PassVaultColor.danger
                            )
                        }
                        PassVaultButton(
                            title: viewModel.isSaving ? "Saving…" : (viewModel.isEditing ? "Save changes" : "Save to vault"),
                            systemImage: viewModel.isSaving ? "arrow.triangle.2.circlepath" : "lock.fill",
                            variant: .primary,
                            action: { save(viewModel: viewModel) },
                            isEnabled: !viewModel.isSaving
                        )
                    }
                    .padding(.horizontal, PassVaultSpacing.medium)
                    .padding(.top, PassVaultSpacing.small)
                    .padding(.bottom, PassVaultSpacing.small)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit \(viewModel.kind.title)" : "New \(viewModel.kind.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    viewModel.imageData = try await item.loadTransferable(type: Data.self)
                    viewModel.mediaType = item.supportedContentTypes.first?.preferredMIMEType
                } catch {
                    viewModel.errorMessage = "The selected image could not be loaded."
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: PassVaultSpacing.medium) {
            VaultIconBadge(systemName: viewModel.kind.systemImage, tint: tint, size: 60)
            VStack(alignment: .leading, spacing: PassVaultSpacing.xxSmall) {
                Text(viewModel.isEditing ? "Refine your private item" : "Keep it only for you")
                    .font(PassVaultTypography.heading2)
                    .foregroundStyle(PassVaultColor.textPrimary)
                Text(description)
                    .font(PassVaultTypography.body)
                    .foregroundStyle(PassVaultColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func loginFields(viewModel: VaultEditorViewModel) -> some View {
        VStack(alignment: .leading, spacing: PassVaultSpacing.small) {
            VaultSectionHeader(title: "Login details")
            VaultEditorField(title: "Title", systemName: "tag.fill") {
                TextField("e.g. Personal email", text: bind(viewModel, \.title))
                    .textInputAutocapitalization(.words)
            }
            VaultEditorField(title: "Username or email", systemName: "person.fill") {
                TextField("name@example.com", text: bind(viewModel, \.username))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            VaultEditorField(title: "Password", systemName: "key.fill") {
                SecureField("Required", text: bind(viewModel, \.password))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .privacySensitive()
            }
            VaultEditorField(title: "Website", systemName: "globe") {
                TextField("Optional", text: bind(viewModel, \.website))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            }
            VaultEditorField(title: "Notes", systemName: "note.text") {
                TextField("Optional", text: bind(viewModel, \.notes), axis: .vertical)
                    .lineLimit(3 ... 6)
            }
        }
    }

    private func noteFields(viewModel: VaultEditorViewModel) -> some View {
        VStack(alignment: .leading, spacing: PassVaultSpacing.small) {
            VaultSectionHeader(title: "Private note")
            VaultEditorField(title: "Title", systemName: "tag.fill") {
                TextField("A title only you will understand", text: bind(viewModel, \.title))
                    .textInputAutocapitalization(.sentences)
            }
            VaultEditorField(title: "Your note", systemName: "note.text") {
                TextEditor(text: bind(viewModel, \.noteBody))
                    .font(PassVaultTypography.bodyLarge)
                    .foregroundStyle(PassVaultColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 220)
            }
        }
    }

    private func imageFields(viewModel: VaultEditorViewModel) -> some View {
        let hasSelectedImage = viewModel.imageData != nil
        let isEditing = viewModel.isEditing
        let pickerTitle = hasSelectedImage
            ? "New image selected"
            : (isEditing ? "Replace encrypted image" : "Choose an image")
        let pickerDescription = !hasSelectedImage && isEditing
            ? "The existing encrypted image stays in place until you choose a replacement."
            : "The selected image is encrypted before it is written to storage."

        return VStack(alignment: .leading, spacing: PassVaultSpacing.small) {
            VaultSectionHeader(title: "Private image")
            VaultEditorField(title: "Title", systemName: "tag.fill") {
                TextField("Describe the image", text: bind(viewModel, \.title))
                    .textInputAutocapitalization(.sentences)
            }

            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                HStack(spacing: PassVaultSpacing.medium) {
                    VaultIconBadge(
                        systemName: hasSelectedImage ? "checkmark.circle.fill" : "photo.badge.plus",
                        tint: hasSelectedImage ? PassVaultColor.success : PassVaultColor.primary,
                        size: 48
                    )
                    VStack(alignment: .leading, spacing: PassVaultSpacing.xxSmall) {
                        Text(pickerTitle)
                            .font(PassVaultTypography.labelLarge)
                            .foregroundStyle(PassVaultColor.textPrimary)
                        Text(pickerDescription)
                            .font(PassVaultTypography.body)
                            .foregroundStyle(PassVaultColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PassVaultColor.textSecondary)
                }
                .padding(PassVaultSpacing.medium)
                .vaultSurface()
            }
            .buttonStyle(.plain)

            VaultEditorField(title: "Notes", systemName: "note.text") {
                TextField("Optional", text: bind(viewModel, \.notes), axis: .vertical)
                    .lineLimit(3 ... 6)
            }
        }
    }

    private func bind<T>(
        _ viewModel: VaultEditorViewModel,
        _ keyPath: ReferenceWritableKeyPath<VaultEditorViewModel, T>
    ) -> Binding<T> {
        Binding(
            get: { viewModel[keyPath: keyPath] },
            set: { viewModel[keyPath: keyPath] = $0 }
        )
    }

    private func save(viewModel: VaultEditorViewModel) {
        Task {
            if await viewModel.save() {
                onSaved()
                dismiss()
            }
        }
    }

    private var tint: Color {
        switch viewModel.kind {
        case .login: PassVaultColor.primary
        case .secureNote: PassVaultColor.accent
        case .image: .pink
        }
    }

    private var description: String {
        switch viewModel.kind {
        case .login: "Save credentials with a label you can recognize at a glance."
        case .secureNote: "Write freely. The contents are encrypted before they are saved."
        case .image: "Select an image to store as encrypted data on this device."
        }
    }
}

private struct VaultEditorField<Content: View>: View {
    let title: String
    let systemName: String
    @ViewBuilder let content: Content

    init(
        title: String,
        systemName: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemName = systemName
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PassVaultSpacing.xSmall) {
            Label(title, systemImage: systemName)
                .font(PassVaultTypography.label)
                .foregroundStyle(PassVaultColor.textSecondary)
            content
                .font(PassVaultTypography.bodyLarge)
                .foregroundStyle(PassVaultColor.textPrimary)
                .padding(PassVaultSpacing.small)
                .background(PassVaultColor.background, in: RoundedRectangle(cornerRadius: PassVaultRadius.input, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PassVaultRadius.input, style: .continuous)
                        .stroke(PassVaultColor.border.opacity(0.55), lineWidth: 0.8)
                }
        }
        .padding(PassVaultSpacing.medium)
        .vaultSurface()
    }
}
