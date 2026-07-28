//
//  VaultServicing.swift
//  iVault
//
//  Created by Tu on 27/7/26.
//

import Foundation

protocol VaultServicing: Sendable {
    var isUnlocked: Bool { get async }

    func unlock() async throws

    func lock() async

    func fetchItemSummaries() async throws -> [VaultItemSummary]

    func fetchEntry(id: UUID) async throws -> VaultEntry

    func createEntry(from draft: VaultItemDraft) async throws -> UUID

    func deleteEntry(id: UUID) async throws

    func updateEntry(
        id: UUID,
        with draft: VaultItemDraft,
    ) async throws
}
