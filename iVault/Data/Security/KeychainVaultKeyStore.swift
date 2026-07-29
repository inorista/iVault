//
//  KeychainVaultKeyStore.swift
//  iVault
//
//  Created by Tu on 28/7/26.
//
import Foundation
import LocalAuthentication
import Security

nonisolated enum VaultKeyStoreError: Error, Equatable, Sendable {
    case itemNotFound
    case interactionNotAllowed
    case authenticationFailed
    case authenticationCancelled
    case invalidReturnedData
    case accessControlCreationFailed
    case unexpectedStatus(OSStatus)
}

nonisolated protocol VaultKeyStoring: Sendable {
    func saveMasterKey(
        _ keyData: Data,
        keyID: UUID
    ) async throws

    func loadMasterKey(
        keyID: UUID,
        reason: String
    ) async throws -> Data

    func deleteMasterKey(
        keyID: UUID,
        reason: String
    ) async throws
}

actor KeychainVaultKeyStore: VaultKeyStoring {
    private let service = "com.dev.ivault.vault-master-key"

    private func account(
        for keyID: UUID
    ) -> String {
        "master-key.\(keyID.uuidString.lowercased())"
    }

    private func identityQuery(
        keyID: UUID
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,
            kSecAttrService as String:
                service,
            kSecAttrAccount as String:
                account(for: keyID),
            kSecAttrSynchronizable as String:
                kCFBooleanFalse as Any,
        ]

        #if os(macOS)
            query[kSecUseDataProtectionKeychain as String] = true
        #endif

        return query
    }

    private func makeAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?

        guard
            let accessControl =
                SecAccessControlCreateWithFlags(
                    nil,
                    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                    .userPresence,
                    &error
                )
        else {
            if let error {
                _ = error.takeRetainedValue()
            }

            throw VaultKeyStoreError
                .accessControlCreationFailed
        }

        return accessControl
    }

    func saveMasterKey(
        _ keyData: Data,
        keyID: UUID
    ) async throws {
        let accessControl = try makeAccessControl()

        var addQuery = identityQuery(keyID: keyID)
        addQuery[kSecValueData as String] = keyData
        addQuery[kSecAttrAccessControl as String] = accessControl

        let addStatus = SecItemAdd(
            addQuery as CFDictionary,
            nil
        )

        switch addStatus {
        case errSecSuccess:
            return

        case errSecDuplicateItem:
            try updateMasterKey(
                keyData,
                keyID: keyID
            )
        case errSecInteractionNotAllowed:
            throw VaultKeyStoreError.interactionNotAllowed
        case errSecAuthFailed:
            throw VaultKeyStoreError.authenticationFailed
        case errSecUserCanceled:
            throw VaultKeyStoreError.authenticationCancelled
        default:
            throw VaultKeyStoreError.unexpectedStatus(addStatus)
        }
    }

    func deleteMasterKey(keyID: UUID, reason: String) async throws {
        let context = LAContext()
        context.localizedReason = reason

        var query = identityQuery(keyID: keyID)
        query[kSecUseAuthenticationContext as String] = context

        let status = SecItemDelete(
            query as CFDictionary
        )

        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        case errSecInteractionNotAllowed:
            throw VaultKeyStoreError.interactionNotAllowed

        case errSecAuthFailed:
            throw VaultKeyStoreError.authenticationFailed

        case errSecUserCanceled:
            throw VaultKeyStoreError.authenticationCancelled

        default:
            throw VaultKeyStoreError.unexpectedStatus(status)

        }
    }

    func loadMasterKey(keyID: UUID, reason: String) async throws -> Data {
        let context = LAContext()
        context.localizedReason = reason

        var query = identityQuery(keyID: keyID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context

        var result: CFTypeRef?

        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw VaultKeyStoreError.invalidReturnedData
            }

            return data

        case errSecItemNotFound:
            throw VaultKeyStoreError.itemNotFound

        case errSecInteractionNotAllowed:
            throw VaultKeyStoreError.interactionNotAllowed

        case errSecAuthFailed:
            throw VaultKeyStoreError.authenticationFailed

        case errSecUserCanceled:
            throw VaultKeyStoreError.authenticationCancelled

        default:
            throw VaultKeyStoreError.unexpectedStatus(status)
        }

    }

    private func updateMasterKey(
        _ keyData: Data,
        keyID: UUID
    ) throws {
        let context = LAContext()
        context.localizedReason = "Authenticate to update the iVault key."

        var query = identityQuery(keyID: keyID)
        query[kSecUseAuthenticationContext as String] = context

        let attributes: [String: Any] = [
            kSecValueData as String: keyData
        ]

        let status = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )

        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            throw VaultKeyStoreError.itemNotFound

        case errSecInteractionNotAllowed:
            throw VaultKeyStoreError.interactionNotAllowed

        case errSecAuthFailed:
            throw VaultKeyStoreError.authenticationFailed

        case errSecUserCanceled:
            throw VaultKeyStoreError.authenticationCancelled

        default:
            throw VaultKeyStoreError.unexpectedStatus(status)
        }

    }
}

/// A per-backup key stored separately from the biometric, device-only vault
/// master key. Synchronizable Keychain makes automatic restore possible on a
/// second device signed into the same iCloud Keychain account.
nonisolated protocol BackupKeyStoring: Sendable {
    func saveBackupKey(_ keyData: Data, backupID: UUID) async throws
    func loadBackupKey(backupID: UUID) async throws -> Data
    func deleteBackupKey(backupID: UUID) async throws
}

actor SynchronizedBackupKeyStore: BackupKeyStoring {
    private let service = "com.dev.ivault.backup-key"

    private func query(for backupID: UUID) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "backup-key.\(backupID.uuidString.lowercased())",
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
        ]

        #if os(macOS)
            query[kSecUseDataProtectionKeychain as String] = true
        #endif

        return query
    }

    func saveBackupKey(_ keyData: Data, backupID: UUID) throws {
        var addQuery = query(for: backupID)
        addQuery[kSecValueData as String] = keyData
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let updateStatus = SecItemUpdate(
                query(for: backupID) as CFDictionary,
                [kSecValueData as String: keyData] as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw VaultKeyStoreError.unexpectedStatus(updateStatus)
            }
        default:
            throw VaultKeyStoreError.unexpectedStatus(status)
        }
    }

    func loadBackupKey(backupID: UUID) throws -> Data {
        var lookup = query(for: backupID)
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw VaultKeyStoreError.invalidReturnedData
            }
            return data
        case errSecItemNotFound:
            throw VaultKeyStoreError.itemNotFound
        default:
            throw VaultKeyStoreError.unexpectedStatus(status)
        }
    }

    func deleteBackupKey(backupID: UUID) throws {
        let status = SecItemDelete(query(for: backupID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw VaultKeyStoreError.unexpectedStatus(status)
        }
    }
}
