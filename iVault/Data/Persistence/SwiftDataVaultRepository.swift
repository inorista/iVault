//
//  SwiftDataVaultRepository.swift
//  iVault
//

import Foundation
import SwiftData

nonisolated protocol VaultRepository: Sendable {
    func fetchStoreState() async throws -> VaultStoreState?
    func saveStoreState(_ state: VaultStoreState) async throws

    func fetchRecords(
        generationID: UUID
    ) async throws -> [StoredVaultRecord]

    func fetchRecord(
        id: UUID,
        generationID: UUID
    ) async throws -> StoredVaultRecord?

    func upsertRecord(
        _ record: StoredVaultRecord
    ) async throws

    func deleteRecord(
        id: UUID,
        generationID: UUID
    ) async throws

    func fetchAsset(
        id: UUID,
        generationID: UUID
    ) async throws -> StoredVaultAsset?

    func fetchAssets(
        generationID: UUID
    ) async throws -> [StoredVaultAsset]

    func upsertAsset(
        _ asset: StoredVaultAsset
    ) async throws

    func deleteAsset(
        id: UUID,
        generationID: UUID
    ) async throws
}

@ModelActor
actor SwiftDataVaultRepository: VaultRepository {
    func fetchStoreState() throws -> VaultStoreState? {
        var descriptor = FetchDescriptor<VaultStoreStateEntity>()
        descriptor.fetchLimit = 1

        guard let entity = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return VaultStoreState(
            activeGenerationID: entity.activeGenerationID,
            activeKeyID: entity.activeKeyID,
            updatedAt: entity.updatedAt
        )
    }

    func saveStoreState(
        _ state: VaultStoreState
    ) throws {
        var descriptor = FetchDescriptor<VaultStoreStateEntity>()
        descriptor.fetchLimit = 1

        if let entity = try modelContext.fetch(descriptor).first {
            entity.activeGenerationID = state.activeGenerationID
            entity.activeKeyID = state.activeKeyID
            entity.updatedAt = state.updatedAt
        } else {
            modelContext.insert(
                VaultStoreStateEntity(
                    activeGenerationID: state.activeGenerationID,
                    activeKeyID: state.activeKeyID,
                    updatedAt: state.updatedAt
                )
            )
        }

        try modelContext.save()
    }

    func fetchRecords(
        generationID: UUID
    ) throws -> [StoredVaultRecord] {
        let targetGenerationID = generationID

        let descriptor = FetchDescriptor<VaultRecordEntity>(
            predicate: #Predicate {
                $0.generationID == targetGenerationID
            },
            sortBy: [
                SortDescriptor(\.modifiedAt, order: .reverse)
            ]
        )

        return try modelContext.fetch(descriptor).map {
            makeStoredRecord(from: $0)
        }
    }

    func fetchRecord(
        id: UUID,
        generationID: UUID
    ) throws -> StoredVaultRecord? {
        let targetID = id
        let targetGenerationID = generationID

        var descriptor = FetchDescriptor<VaultRecordEntity>(
            predicate: #Predicate {
                $0.id == targetID &&
                $0.generationID == targetGenerationID
            }
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first.map {
            makeStoredRecord(from: $0)
        }
    }

    func upsertRecord(
        _ record: StoredVaultRecord
    ) throws {
        let targetID = record.id
        let targetGenerationID = record.generationID

        var descriptor = FetchDescriptor<VaultRecordEntity>(
            predicate: #Predicate {
                $0.id == targetID &&
                $0.generationID == targetGenerationID
            }
        )
        descriptor.fetchLimit = 1

        if let entity = try modelContext.fetch(descriptor).first {
            entity.modifiedAt = record.modifiedAt
            entity.revision = record.revision
            entity.envelopeVersion = record.payloadEnvelope.formatVersion
            entity.keyVersion = record.payloadEnvelope.keyVersion
            entity.summaryCiphertext = record.summaryEnvelope.combined
            entity.payloadCiphertext = record.payloadEnvelope.combined
        } else {
            modelContext.insert(
                VaultRecordEntity(
                    id: record.id,
                    generationID: record.generationID,
                    modifiedAt: record.modifiedAt,
                    revision: record.revision,
                    envelopeVersion: record.payloadEnvelope.formatVersion,
                    keyVersion: record.payloadEnvelope.keyVersion,
                    summaryCiphertext: record.summaryEnvelope.combined,
                    payloadCiphertext: record.payloadEnvelope.combined
                )
            )
        }

        try modelContext.save()
    }

    func deleteRecord(
        id: UUID,
        generationID: UUID
    ) throws {
        let targetID = id
        let targetGenerationID = generationID

        let descriptor = FetchDescriptor<VaultRecordEntity>(
            predicate: #Predicate {
                $0.id == targetID &&
                $0.generationID == targetGenerationID
            }
        )

        try modelContext.fetch(descriptor).forEach(modelContext.delete)
        try modelContext.save()
    }

    func fetchAsset(
        id: UUID,
        generationID: UUID
    ) throws -> StoredVaultAsset? {
        let targetID = id
        let targetGenerationID = generationID

        var descriptor = FetchDescriptor<VaultAssetEntity>(
            predicate: #Predicate {
                $0.id == targetID &&
                $0.generationID == targetGenerationID
            }
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first.map {
            makeStoredAsset(from: $0)
        }
    }

    func fetchAssets(
        generationID: UUID
    ) throws -> [StoredVaultAsset] {
        let targetGenerationID = generationID
        let descriptor = FetchDescriptor<VaultAssetEntity>(
            predicate: #Predicate {
                $0.generationID == targetGenerationID
            }
        )

        return try modelContext.fetch(descriptor).map {
            makeStoredAsset(from: $0)
        }
    }

    func upsertAsset(
        _ asset: StoredVaultAsset
    ) throws {
        let targetID = asset.id
        let targetGenerationID = asset.generationID

        var descriptor = FetchDescriptor<VaultAssetEntity>(
            predicate: #Predicate {
                $0.id == targetID &&
                $0.generationID == targetGenerationID
            }
        )
        descriptor.fetchLimit = 1

        if let entity = try modelContext.fetch(descriptor).first {
            entity.byteCount = asset.byteCount
            entity.envelopeVersion = asset.wrappedKey.formatVersion
            entity.keyVersion = asset.wrappedKey.keyVersion
            entity.wrappedKeyCiphertext = asset.wrappedKey.combined
        } else {
            modelContext.insert(
                VaultAssetEntity(
                    id: asset.id,
                    generationID: asset.generationID,
                    byteCount: asset.byteCount,
                    envelopeVersion: asset.wrappedKey.formatVersion,
                    keyVersion: asset.wrappedKey.keyVersion,
                    wrappedKeyCiphertext: asset.wrappedKey.combined
                )
            )
        }

        try modelContext.save()
    }

    func deleteAsset(
        id: UUID,
        generationID: UUID
    ) throws {
        let targetID = id
        let targetGenerationID = generationID

        let descriptor = FetchDescriptor<VaultAssetEntity>(
            predicate: #Predicate {
                $0.id == targetID &&
                $0.generationID == targetGenerationID
            }
        )

        try modelContext.fetch(descriptor).forEach(modelContext.delete)
        try modelContext.save()
    }

    private func makeStoredRecord(
        from entity: VaultRecordEntity
    ) -> StoredVaultRecord {
        StoredVaultRecord(
            id: entity.id,
            generationID: entity.generationID,
            modifiedAt: entity.modifiedAt,
            revision: entity.revision,
            summaryEnvelope: EncryptedEnvelope(
                formatVersion: entity.envelopeVersion,
                keyVersion: entity.keyVersion,
                combined: entity.summaryCiphertext
            ),
            payloadEnvelope: EncryptedEnvelope(
                formatVersion: entity.envelopeVersion,
                keyVersion: entity.keyVersion,
                combined: entity.payloadCiphertext
            )
        )
    }

    private func makeStoredAsset(
        from entity: VaultAssetEntity
    ) -> StoredVaultAsset {
        StoredVaultAsset(
            id: entity.id,
            generationID: entity.generationID,
            byteCount: entity.byteCount,
            wrappedKey: EncryptedEnvelope(
                formatVersion: entity.envelopeVersion,
                keyVersion: entity.keyVersion,
                combined: entity.wrappedKeyCiphertext
            )
        )
    }
}
