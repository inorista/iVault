import SwiftUI

struct BackupView: View {
    @State private var viewModel: BackupViewModel
    @State private var backupPendingRestore: BackupInfo?
    @State private var backupPendingRecoveryCode: BackupInfo?
    @State private var backupPendingDeletion: BackupInfo?
    @State private var recoveryCode = ""

    init(backupService: any BackupServicing) {
        _viewModel = State(initialValue: BackupViewModel(backupService: backupService))
    }

    var body: some View {
        ZStack {
            VaultScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: PassVaultSpacing.large) {
                    header
                    if let errorMessage = viewModel.errorMessage {
                        VaultInlineMessage(
                            message: errorMessage,
                            systemName: "exclamationmark.triangle.fill",
                            tint: PassVaultColor.danger
                        )
                    }
                    backupAction
                    VaultSectionHeader(title: "Available backups", subtitle: "Tap a snapshot to restore it on this device.")
                    backupList
                }
                .padding(.horizontal, PassVaultSpacing.medium)
                .padding(.vertical, PassVaultSpacing.large)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .refreshable { await viewModel.load() }
        }
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .confirmationDialog(
            "Restore this backup?",
            isPresented: backupBinding(backupPendingRestore),
            titleVisibility: .visible
        ) {
            Button("Restore using iCloud Keychain") {
                guard let backup = backupPendingRestore else { return }
                Task {
                    if await viewModel.restore(backup: backup, recoveryMethod: .synchronizedKeychain) {
                        backupPendingRestore = nil
                    } else if viewModel.errorMessage != nil {
                        backupPendingRecoveryCode = backup
                        backupPendingRestore = nil
                    }
                }
            }
            Button("Use recovery code") {
                backupPendingRecoveryCode = backupPendingRestore
                backupPendingRestore = nil
            }
        } message: {
            Text("Restoring replaces the active vault on this device with the selected encrypted snapshot.")
        }
        .confirmationDialog(
            "Delete this backup?",
            isPresented: backupBinding(backupPendingDeletion),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let backup = backupPendingDeletion {
                    Task { await viewModel.delete(backup) }
                }
                backupPendingDeletion = nil
            }
        } message: {
            Text("This deletes the encrypted snapshot from your private iCloud database.")
        }
        .sheet(item: $backupPendingRecoveryCode) { backup in
            RecoveryCodeEntryView(recoveryCode: $recoveryCode, isWorking: viewModel.isWorking) {
                Task {
                    if await viewModel.restore(backup: backup, recoveryMethod: .recoveryCode(recoveryCode)) {
                        recoveryCode = ""
                        backupPendingRecoveryCode = nil
                    }
                }
            } onCancel: {
                recoveryCode = ""
                backupPendingRecoveryCode = nil
            }
        }
        .sheet(isPresented: newRecoveryCodeBinding) {
            RecoveryCodeView(code: viewModel.newRecoveryCode ?? "") {
                viewModel.newRecoveryCode = nil
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: PassVaultSpacing.medium) {
            VaultIconBadge(systemName: "icloud.fill", tint: PassVaultColor.primary, size: 62)
            VStack(alignment: .leading, spacing: PassVaultSpacing.xxSmall) {
                Text("Your encrypted safety net")
                    .font(PassVaultTypography.heading2)
                    .foregroundStyle(PassVaultColor.textPrimary)
                Text("iCloud sees an encrypted snapshot, never the contents of your vault.")
                    .font(PassVaultTypography.body)
                    .foregroundStyle(PassVaultColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var backupAction: some View {
        VStack(alignment: .leading, spacing: PassVaultSpacing.medium) {
            VaultInlineMessage(
                message: "Snapshots include encrypted records, encrypted image files, and a wrapped vault key.",
                systemName: "checkmark.shield.fill"
            )
            PassVaultButton(
                title: viewModel.isWorking ? "Creating encrypted backup…" : "Create encrypted backup",
                systemImage: "icloud.and.arrow.up.fill",
                variant: .primary,
                action: { Task { await viewModel.createBackup() } },
                isEnabled: !viewModel.isWorking
            )
            .accessibilityIdentifier("createBackupButton")
        }
        .padding(PassVaultSpacing.medium)
        .vaultSurface(elevated: true)
    }

    @ViewBuilder
    private var backupList: some View {
        if viewModel.isLoading {
            ProgressView("Checking iCloud…")
                .frame(maxWidth: .infinity, minHeight: 160)
                .vaultSurface()
        } else if viewModel.backups.isEmpty {
            VaultEmptyState(
                systemName: "icloud.slash",
                title: "No backups yet",
                message: "Create your first encrypted snapshot whenever you are ready."
            )
        } else {
            VStack(spacing: 12) {
                ForEach(viewModel.backups) { backup in
                    Button { backupPendingRestore = backup } label: {
                        BackupCard(backup: backup)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Restore", systemImage: "arrow.clockwise") {
                            backupPendingRestore = backup
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            backupPendingDeletion = backup
                        }
                    }
                }
            }
        }
    }

    private func backupBinding(_ backup: BackupInfo?) -> Binding<Bool> {
        Binding(
            get: { backup != nil },
            set: { isPresented in
                if !isPresented {
                    if backup?.id == backupPendingRestore?.id { backupPendingRestore = nil }
                    if backup?.id == backupPendingDeletion?.id { backupPendingDeletion = nil }
                }
            }
        )
    }

    private var newRecoveryCodeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.newRecoveryCode != nil },
            set: { if !$0 { viewModel.newRecoveryCode = nil } }
        )
    }
}

private struct BackupCard: View {
    let backup: BackupInfo

    var body: some View {
        HStack(spacing: PassVaultSpacing.small) {
            VaultIconBadge(systemName: "icloud.fill", tint: PassVaultColor.primary, size: 48)
            VStack(alignment: .leading, spacing: PassVaultSpacing.xxSmall) {
                Text(backup.createdAt, format: .dateTime.year().month().day().hour().minute())
                    .font(PassVaultTypography.labelLarge)
                    .foregroundStyle(PassVaultColor.textPrimary)
                Text("\(backup.recordCount) items · \(backup.assetCount) images · \(backup.encryptedByteCount.formatted(.byteCount(style: .file)))")
                    .font(PassVaultTypography.body)
                    .foregroundStyle(PassVaultColor.textSecondary)
            }
            Spacer(minLength: PassVaultSpacing.small)
            Image(systemName: "arrow.clockwise")
                .font(.body.weight(.bold))
                .foregroundStyle(PassVaultColor.primary)
        }
        .padding(PassVaultSpacing.medium)
        .vaultSurface()
        .accessibilityElement(children: .combine)
    }
}

private struct RecoveryCodeEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var recoveryCode: String
    let isWorking: Bool
    let onRestore: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                VaultScreenBackground()
                VStack(alignment: .leading, spacing: PassVaultSpacing.large) {
                    VaultIconBadge(systemName: "key.fill", tint: PassVaultColor.primary, size: 62)
                    VStack(alignment: .leading, spacing: PassVaultSpacing.xSmall) {
                        Text("Enter your recovery code")
                            .font(PassVaultTypography.heading2)
                            .foregroundStyle(PassVaultColor.textPrimary)
                        Text("Spaces and hyphens are ignored. The code is only used to unlock this selected backup.")
                            .font(PassVaultTypography.body)
                            .foregroundStyle(PassVaultColor.textSecondary)
                    }
                    TextField("Recovery code", text: $recoveryCode, axis: .vertical)
                        .font(PassVaultTypography.mono)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(PassVaultSpacing.medium)
                        .background(PassVaultColor.surface, in: RoundedRectangle(cornerRadius: PassVaultRadius.input, style: .continuous))
                    Spacer()
                }
                .padding(PassVaultSpacing.medium)
            }
            .navigationTitle("Recovery code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isWorking ? "Restoring…" : "Restore", action: onRestore)
                        .disabled(recoveryCode.isEmpty || isWorking)
                }
            }
        }
    }
}

private struct RecoveryCodeView: View {
    @Environment(\.dismiss) private var dismiss
    let code: String
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                VaultScreenBackground()
                VStack(alignment: .leading, spacing: PassVaultSpacing.large) {
                    VaultIconBadge(systemName: "key.fill", tint: PassVaultColor.accent, size: 64)
                    VStack(alignment: .leading, spacing: PassVaultSpacing.xSmall) {
                        Text("Save this recovery code now")
                            .font(PassVaultTypography.heading2)
                            .foregroundStyle(PassVaultColor.textPrimary)
                        Text("It can restore this backup on a device where iCloud Keychain is unavailable. iVault will not show or store it again.")
                            .font(PassVaultTypography.body)
                            .foregroundStyle(PassVaultColor.textSecondary)
                    }
                    Text(code)
                        .font(.system(.title3, design: .monospaced, weight: .semibold))
                        .textSelection(.enabled)
                        .padding(PassVaultSpacing.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PassVaultColor.surface, in: RoundedRectangle(cornerRadius: PassVaultRadius.input, style: .continuous))
                        .privacySensitive()
                    Spacer()
                }
                .padding(PassVaultSpacing.medium)
            }
            .navigationTitle("Recovery code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("I saved it") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
