//
//  File.swift
//  iVault
//
//  Created by Tu on 27/7/26.
//

import Foundation

nonisolated enum EncryptedAssetStoreError: Error, Equatable, Sendable {
    case assetNotFound(UUID)
    case cannotCreateDirectory
    case cannotWrite
    case cannotRead
    case cannotDelete
}

actor EncryptedAssetStore {
    private let rootURL: URL

    init(rootURL: URL? = nil) throws {
        if let rootURL {
            self.rootURL = rootURL
        } else {
            guard
                let applicationSupport = FileManager.default.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask
                ).first

            else {
                throw EncryptedAssetStoreError.cannotCreateDirectory
            }

            self.rootURL = applicationSupport.appendingPathComponent(
                "VaultAssets",
                isDirectory: true
            )
        }
        do {
            try FileManager.default.createDirectory(
                at: self.rootURL,
                withIntermediateDirectories: true
            )

            try FileManager.default.setAttributes(
                [
                    .protectionKey: FileProtectionType.complete
                ],
                ofItemAtPath: self.rootURL.path
            )
        } catch {
            throw EncryptedAssetStoreError.cannotCreateDirectory
        }
    }

    func write(
        ciphertext: Data,
        assetID: UUID
    ) throws {
        let destination = fileURL(for: assetID)

        do {
            try ciphertext.write(
                to: destination,
                options: [
                    .atomic,
                    .completeFileProtection,
                ]
            )
        } catch {
            throw EncryptedAssetStoreError.cannotWrite
        }
    }

    func read(
        assetID: UUID
    ) throws -> Data {
        let source = fileURL(for: assetID)

        guard
            FileManager.default.fileExists(
                atPath: source.path
            )
        else {
            throw
                EncryptedAssetStoreError
                .assetNotFound(assetID)
        }

        do {
            return try Data(contentsOf: source)
        } catch {
            throw EncryptedAssetStoreError.cannotRead
        }
    }

    func delete(
        assetID: UUID
    ) throws {
        let destination = fileURL(for: assetID)

        guard
            FileManager.default.fileExists(
                atPath: destination.path
            )
        else {
            return
        }

        do {
            try FileManager.default.removeItem(
                at: destination
            )
        } catch {
            throw EncryptedAssetStoreError.cannotDelete
        }
    }

    private func fileURL(
        for assetID: UUID
    ) -> URL {
        rootURL.appendingPathComponent(
            "\(assetID.uuidString.lowercased()).ivasset",
            isDirectory: false
        )
    }
}
