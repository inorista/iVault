//
//  VaultStoredModels.swift
//  iVault
//
//  Created by Tu on 28/7/26.
//
import Foundation

nonisolated struct StoredVaultRecord: Codable, Equatable, Sendable {
    let id: UUID
    let generationID: UUID
    let modifiedAt: Date
    let revision: Int64
    let summaryEnvelope: EncryptedEnvelope
    let payloadEnvelope: EncryptedEnvelope
}

nonisolated struct StoredVaultAsset: Codable, Equatable, Sendable {
    let id: UUID
    let generationID: UUID
    let byteCount: Int64
    let wrappedKey: EncryptedEnvelope
}

nonisolated struct VaultStoreState: Codable, Equatable, Sendable {
    let activeGenerationID: UUID
    let activeKeyID: UUID
    let updatedAt: Date
}
