//
//  BackupRecoveryMethod.swift
//  iVault
//
//  Created by Tu on 28/7/26.
//

import Foundation

nonisolated enum BackupRecoveryMethod: Sendable {
    case synchronizedKeychain

    case recoveryCode(String)
}
