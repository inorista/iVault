//
//  KeychainVaultKeyStore.swift
//  iVault
//
//  Created by Tu on 28/7/26.
//
import Foundation
import LocalAuthentication
import Security

enum VaultKeyStoreError: Error, Equatable, Sendable {
    case itemNotFound
    case interactionNotAllowed
    case authenticationFailed
    case authenticationCancelled
    case invalidReturnedData
    case accessControlCreationFailed
    case unexpectedStatus(OSStatus)
}

protocol VaultKeyStoring: Sendable {
    func saveMasterKey(
        _ keyData: Data,
        keyId: UUID
    ) async throws

    func loadMasterKey(
        keyId: UUID,
        reason: String
    ) async throws -> Data

    func deleteMasterKey(
        keyId: UUID,
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
        keyId: UUID
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,
            kSecAttrService as String:
                service,
            kSecAttrAccount as String:
                account(for: keyId),
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
        keyId: UUID
    ) async throws {
        let accessControl = try makeAccessControl()

        var addQuery = identityQuery(keyId: keyId)
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
                keyId: keyId
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

    func deleteMasterKey(keyId: UUID, reason: String) async throws {
        let context = LAContext()

        var query = identityQuery(keyId: keyId)
        query[kSecUseAuthenticationContext as String] = context
        query[kSecUseOperationPrompt as String] = reason

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

    func loadMasterKey(keyId: UUID, reason: String) async throws -> Data {
        let context = LAContext()

        var query = identityQuery(keyId: keyId)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context
        query[kSecUseOperationPrompt as String] = reason

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
        keyId: UUID
    ) throws {
        let context = LAContext()

        var query = identityQuery(keyId: keyId)
        query[kSecUseAuthenticationContext as String] = context
        query[kSecUseOperationPrompt as String] =
            "Authenticate to update the iVault key."

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
