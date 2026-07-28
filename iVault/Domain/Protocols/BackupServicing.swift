//
//  BackupServicing.swift
//  iVault
//
//  Created by Tu on 27/7/26.
//

import Foundation

protocol BackupServicing: Sendable {
    func fetchAvailableBackups() async throws -> [BackupInfo]

    func createBackup() async throws -> BackupInfo

    func restoreBackup(id: UUID, using recoveryMethod: BackupRecoveryMethod)
        async throws

    func deleteBackup(id: UUID) async throws

    
}
