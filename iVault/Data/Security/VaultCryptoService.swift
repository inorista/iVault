//
//  VaultCryptoService.swift
//  iVault
//
//  Created by Tu on 27/7/26.
//

import CryptoKit
import Foundation

actor VaultCryptoService {
    private static let formatVersion = 1

    func generateMasterKey() -> VaultMasterKey {
        VaultMasterKey()
    }

    func restoreMasterKey(
        from data: Data
    ) throws -> VaultMasterKey {
        try VaultMasterKey(rawData: data)
    }

    func sealAsset(
        _ plainText: Data,
        assetID: UUID,
        generationID: UUID,
        keyVersion: Int,
        masterKey: VaultMasterKey
    ) throws -> EncryptedAssetPackage {
        let assetKey = SymmetricKey(size: .bits256)

        let assetAAD = try makeAAD(
            recordID: assetID,
            generationID: generationID,
            purpose: .assetData,
            keyVersion: keyVersion
        )

        let assetBox: AES.GCM.SealedBox

        do {
            assetBox = try AES.GCM.seal(
                plainText,
                using: assetKey,
                authenticating: assetAAD
            )
        } catch {
            throw VaultCryptoServiceError.encryptionFailed
        }

        guard let ciphertext = assetBox.combined else {
            throw VaultCryptoServiceError.combinedRepresentationUnavailable
        }

        let assetKeyData = assetKey.withUnsafeBytes {
            Data($0)
        }

        let wrappedKey = try seal(
            assetKeyData,
            recordID: assetID,
            generationID: generationID,
            purpose: .assetKey,
            keyVersion: keyVersion,
            masterKey: masterKey
        )

        return EncryptedAssetPackage(
            ciphertextCombined: ciphertext,
            wrappedKey: wrappedKey
        )
    }

    func openAsset(
        package: EncryptedAssetPackage,
        assetID: UUID,
        generationID: UUID,
        masterKey: VaultMasterKey
    ) throws -> Data {
        let assetKeyData = try open(
            Data.self,
            envelope: package.wrappedKey,
            recordID: assetID,
            generationID: generationID,
            purpose: .assetKey,
            masterKey: masterKey
        )

        guard assetKeyData.count == 32 else {
            throw VaultCryptoServiceError.invalidMasterKey
        }

        let assetKey = SymmetricKey(data: assetKeyData)

        let aad = try makeAAD(
            recordID: assetID,
            generationID: generationID,
            purpose: .assetData,
            keyVersion: package.wrappedKey.keyVersion
        )

        do {
            let box = try AES.GCM.SealedBox(
                combined: package.ciphertextCombined
            )
            return try AES.GCM.open(box, using: assetKey, authenticating: aad)
        } catch {
            throw VaultCryptoServiceError.authenticationFailed
        }
    }

    func open<T>(
        _ type: T.Type,
        envelope: EncryptedEnvelope,
        recordID: UUID,
        generationID: UUID,
        purpose: VaultCipherPurpose,
        masterKey: VaultMasterKey

    ) throws -> T where T: Decodable & Sendable {
        guard envelope.formatVersion == Self.formatVersion else {
            throw VaultCryptoServiceError.unsupportedEnvelopeVersion(
                envelope.formatVersion
            )
        }

        let derivedKey = deriveKey(
            from: masterKey,
            recordID: recordID,
            generationID: generationID,
            purpose: purpose,
            keyVersion: envelope.keyVersion
        )

        let aad = try makeAAD(
            recordID: recordID,
            generationID: generationID,
            purpose: purpose,
            keyVersion: envelope.keyVersion
        )

        let plainText: Data

        do {
            let sealedBox = try AES.GCM.SealedBox(
                combined: envelope.combined
            )

            plainText = try AES.GCM.open(
                sealedBox,
                using: derivedKey,
                authenticating: aad
            )
        } catch {
            throw VaultCryptoServiceError.authenticationFailed
        }
        do {
            return try makeDecoder().decode(T.self, from: plainText)
        } catch {
            throw VaultCryptoServiceError.decodingFailed
        }
    }

    func seal<T>(
        _ value: T,
        recordID: UUID,
        generationID: UUID,
        purpose: VaultCipherPurpose,
        keyVersion: Int,
        masterKey: VaultMasterKey

    ) throws -> EncryptedEnvelope where T: Encodable & Sendable {
        let plainText: Data

        do {
            plainText = try makeEncoder().encode(value)
        } catch {
            throw VaultCryptoServiceError.encodingFailed
        }

        let derivedKey = deriveKey(
            from: masterKey,
            recordID: recordID,
            generationID: generationID,
            purpose: purpose,
            keyVersion: keyVersion
        )

        let aad = try makeAAD(
            recordID: recordID,
            generationID: generationID,
            purpose: purpose,
            keyVersion: keyVersion
        )

        do {
            let sealedBox = try AES.GCM.seal(
                plainText,
                using: derivedKey,
                authenticating: aad
            )

            guard let combined = sealedBox.combined else {
                throw VaultCryptoServiceError.combinedRepresentationUnavailable
            }

            return EncryptedEnvelope(
                formatVersion: Self.formatVersion,
                keyVersion: keyVersion,
                combined: combined
            )
        } catch let error as VaultCryptoServiceError {
            throw error
        } catch {
            throw VaultCryptoServiceError.encryptionFailed
        }
    }

    private func makeAAD(
        recordID: UUID,
        generationID: UUID,
        purpose: VaultCipherPurpose,
        keyVersion: Int
    ) throws -> Data {
        let context = VaultCipherContext(
            formatVersion: Self.formatVersion,
            keyVersion: keyVersion,
            recordID: recordID,
            generationID: generationID,
            purpose: purpose
        )

        do {
            return try makeEncoder().encode(context)

        } catch {
            throw VaultCryptoServiceError.encodingFailed
        }
    }

    private func deriveKey(
        from masterKey: VaultMasterKey,
        recordID: UUID,
        generationID: UUID,
        purpose: VaultCipherPurpose,
        keyVersion: Int
    ) -> SymmetricKey {
        let saltString = [
            recordID.uuidString.lowercased(),
            generationID.uuidString.lowercased(),
        ].joined(separator: ":")

        let infoString = [
            "com.dev.ivault",
            purpose.rawValue,
            "key-version-\(keyVersion)",
        ].joined(separator: ":")

        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterKey.value,
            salt: Data(saltString.utf8),
            info: Data(infoString.utf8),
            outputByteCount: 32
        )
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

}

nonisolated enum VaultCryptoServiceError: Error, Equatable, Sendable {
    case invalidMasterKey
    case unsupportedEnvelopeVersion(Int)
    case combinedRepresentationUnavailable
    case encodingFailed
    case decodingFailed
    case encryptionFailed
    case authenticationFailed
}
nonisolated enum VaultCipherPurpose: String, Codable, Sendable {
    case summary
    case payload
    case assetKey
    case assetData
    case backupManifest
    case backupMasterKey
}

nonisolated struct VaultMasterKey: Sendable {
    let value: SymmetricKey

    init() {
        value = SymmetricKey(size: .bits256)
    }

    init(rawData: Data) throws {
        guard rawData.count == 32 else {
            throw VaultCryptoServiceError.invalidMasterKey
        }

        value = SymmetricKey(data: rawData)
    }

    var rawData: Data {
        value.withUnsafeBytes {
            Data($0)
        }
    }
}

nonisolated struct EncryptedEnvelope: Codable, Equatable, Sendable {
    let formatVersion: Int
    let keyVersion: Int
    let combined: Data
}

nonisolated struct EncryptedAssetPackage: Equatable, Sendable {
    let ciphertextCombined: Data
    let wrappedKey: EncryptedEnvelope
}

nonisolated private struct VaultCipherContext: Codable, Sendable {
    let formatVersion: Int
    let keyVersion: Int
    let recordID: UUID
    let generationID: UUID
    let purpose: VaultCipherPurpose
}
