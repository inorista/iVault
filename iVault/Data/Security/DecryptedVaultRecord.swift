//
//  DecryptedVaultRecord.swift
//  iVault
//
//  Created by Tu on 28/7/26.
//

import Foundation

nonisolated struct DecryptedVaultRecord: Codable, Equatable, Sendable {
    let createdAt: Date
    let modifiedAt: Date
    let payload: VaultPayload
}
