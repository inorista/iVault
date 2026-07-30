//
//  VaultSchemaV1.swift
//  iVault
//
//  Created by Tu on 28/7/26.
//

import Foundation
import SwiftData

enum VaultMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            VaultSchemaV1.self
        ]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum VaultSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            VaultRecord.self,
            VaultAsset.self,
            StoreState.self,
        ]
    }

    @Model
    final class VaultRecord {
        var id: UUID
        var generationID: UUID
        var modifiedAt: Date
        var revision: Int64

        var envelopeVersion: Int
        var keyVersion: Int

        var summaryCiphertext: Data
        var payloadCiphertext: Data

        init(
            id: UUID,
            generationID: UUID,
            modifiedAt: Date,
            revision: Int64,
            envelopeVersion: Int,
            keyVersion: Int,
            summaryCiphertext: Data,
            payloadCiphertext: Data
        ) {
            self.id = id
            self.generationID = generationID
            self.modifiedAt = modifiedAt
            self.revision = revision
            self.envelopeVersion = envelopeVersion
            self.keyVersion = keyVersion
            self.summaryCiphertext = summaryCiphertext
            self.payloadCiphertext = payloadCiphertext
        }
    }

    @Model
    final class VaultAsset {
        var id: UUID
        var generationID: UUID
        var byteCount: Int64

        var envelopeVersion: Int
        var keyVersion: Int
        var wrappedKeyCiphertext: Data

        init(
            id: UUID,
            generationID: UUID,
            byteCount: Int64,
            envelopeVersion: Int,
            keyVersion: Int,
            wrappedKeyCiphertext: Data
        ) {
            self.id = id
            self.generationID = generationID
            self.byteCount = byteCount
            self.envelopeVersion = envelopeVersion
            self.keyVersion = keyVersion
            self.wrappedKeyCiphertext = wrappedKeyCiphertext
        }
    }

    @Model
    final class StoreState {
        var activeGenerationID: UUID
        var activeKeyID: UUID
        var updatedAt: Date
        init(activeGenerationID: UUID, activeKeyID: UUID, updatedAt: Date) {
            self.activeGenerationID = activeGenerationID
            self.activeKeyID = activeKeyID
            self.updatedAt = updatedAt
        }
    }
}

typealias VaultRecordEntity =
    VaultSchemaV1.VaultRecord

typealias VaultAssetEntity =
    VaultSchemaV1.VaultAsset

typealias VaultStoreStateEntity =
    VaultSchemaV1.StoreState
