import SwiftUI

struct VaultListView: View {
    @State private var viewModel: VaultListViewModel
    @State private var router = VaultRouter()
    @State private var selectedKind: VaultItemKind?
    @State private var itemPendingDeletion: VaultItemSummary?

    init(vaultService: any VaultServicing) {
        _viewModel = State(initialValue: VaultListViewModel(vaultService: vaultService))
    }

    var body: some View {
        @Bindable var router = router
        @Bindable var viewModel = viewModel

        NavigationStack(path: $router.path) {
            ZStack {
                VaultScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: PassVaultSpacing.large) {
                        header
                        quickAdd
                        content
                    }
                    .padding(.horizontal, PassVaultSpacing.medium)
                    .padding(.vertical, PassVaultSpacing.large)
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .refreshable { await viewModel.load() }
            }
            .navigationTitle("Vault")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "Search titles and details")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(VaultItemKind.allCases) { kind in
                            Button {
                                selectedKind = kind
                            } label: {
                                Label("New \(kind.title)", systemImage: kind.systemImage)
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.bold))
                    }
                    .accessibilityLabel("Add vault item")
                    .accessibilityIdentifier("addVaultItemButton")
                }
            }
            .navigationDestination(for: VaultRoute.self) { route in
                switch route {
                case .detail(let id):
                    VaultDetailView(
                        vaultService: viewModel.vaultService,
                        entryID: id,
                        onChanged: { Task { await viewModel.load() } },
                        onDeleted: {
                            router.popToRoot()
                            Task { await viewModel.load() }
                        }
                    )
                }
            }
        }
        .task { await viewModel.load() }
        .sheet(item: $selectedKind) { kind in
            VaultEditorView(vaultService: viewModel.vaultService, kind: kind) {
                Task { await viewModel.load() }
            }
        }
        .confirmationDialog(
            "Delete \(itemPendingDeletion?.title ?? "item")?",
            isPresented: Binding(
                get: { itemPendingDeletion != nil },
                set: { if !$0 { itemPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let item = itemPendingDeletion {
                    Task { await viewModel.delete(item) }
                }
                itemPendingDeletion = nil
            }
        } message: {
            Text("This removes the encrypted item and any encrypted image from this device.")
        }
        .alert("Vault error", isPresented: errorBinding) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: PassVaultSpacing.medium) {
            VStack(alignment: .leading, spacing: PassVaultSpacing.xxSmall) {
                Text("Your private collection")
                    .font(PassVaultTypography.heading1)
                    .foregroundStyle(PassVaultColor.textPrimary)
                Text("Passwords, notes, and images — encrypted before storage.")
                    .font(PassVaultTypography.body)
                    .foregroundStyle(PassVaultColor.textSecondary)
            }
            Spacer(minLength: 0)
            VaultIconBadge(systemName: "lock.fill", tint: PassVaultColor.primary, size: 56)
        }
    }

    private var quickAdd: some View {
        VStack(alignment: .leading, spacing: PassVaultSpacing.small) {
            VaultSectionHeader(title: "Create something private")
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(VaultItemKind.allCases) { kind in
                        Button {
                            selectedKind = kind
                        } label: {
                            Label("New \(kind.title)", systemImage: kind.systemImage)
                                .font(PassVaultTypography.label)
                                .foregroundStyle(PassVaultColor.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .background(PassVaultColor.surface, in: Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(PassVaultColor.border.opacity(0.55), lineWidth: 0.8)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            ProgressView("Decrypting your vault…")
                .frame(maxWidth: .infinity, minHeight: 190)
                .vaultSurface()
        } else if viewModel.filteredItems.isEmpty {
            VaultEmptyState(
                systemName: viewModel.searchText.isEmpty ? "lock" : "magnifyingglass",
                title: viewModel.searchText.isEmpty ? "Your vault is ready" : "No matching items",
                message: viewModel.searchText.isEmpty
                    ? "Create a login, private note, or encrypted image to begin."
                    : "Try another title, username, or description."
            )
        } else {
            VStack(spacing: 12) {
                ForEach(viewModel.filteredItems) { item in
                    NavigationLink(value: VaultRoute.detail(item.id)) {
                        VaultSummaryCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            itemPendingDeletion = item
                        }
                    }
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

private struct VaultSummaryCard: View {
    let item: VaultItemSummary

    var body: some View {
        HStack(spacing: PassVaultSpacing.small) {
            VaultIconBadge(systemName: item.kind.systemImage, tint: tint, size: 48)
            VStack(alignment: .leading, spacing: PassVaultSpacing.xxSmall) {
                Text(item.title)
                    .font(PassVaultTypography.labelLarge)
                    .foregroundStyle(PassVaultColor.textPrimary)
                    .lineLimit(1)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(PassVaultTypography.body)
                        .foregroundStyle(PassVaultColor.textSecondary)
                        .lineLimit(1)
                } else {
                    Text(item.kind.title)
                        .font(PassVaultTypography.body)
                        .foregroundStyle(PassVaultColor.textSecondary)
                }
            }
            Spacer(minLength: PassVaultSpacing.xSmall)
            VStack(alignment: .trailing, spacing: 7) {
                Text(item.modifiedAt, format: .dateTime.month(.abbreviated).day())
                    .font(PassVaultTypography.caption)
                    .foregroundStyle(PassVaultColor.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PassVaultColor.textSecondary.opacity(0.75))
            }
        }
        .padding(PassVaultSpacing.medium)
        .vaultSurface()
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch item.kind {
        case .login: PassVaultColor.primary
        case .secureNote: PassVaultColor.accent
        case .image: .pink
        }
    }
}
