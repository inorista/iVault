//
//  DecryptedVaultSummary.swift
//  iVault
//
//  Created by Tu on 28/7/26.
//

import Foundation

struct DecryptedVaultSummary: Codable, Equatable, Sendable {
    let kind: VaultItemKind
    let title: String
    let subtitle: String?
    let modifiedAt: Date
}
