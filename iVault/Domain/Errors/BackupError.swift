//
//  BackupError.swift
//  iVault
//
//  Created by Tu on 27/7/26.
//

import Foundation

/// A domain-level failure while creating or restoring an iCloud backup.
///
/// CloudKit-specific errors are mapped to this type by the backup service.
nonisolated enum BackupError: Error, Equatable, Sendable {
    case cloudAccountUnavailable
    case cloudConfigurationInvalid
    case networkUnavailable
    case quotaExceeded
    case backupNotFound(id: UUID)
    case backupIncomplete(id: UUID)
    case unsupportedFormat(version: Int)
    case integrityCheckFailed
    case recoveryKeyRequired
    case invalidRecoveryKey
    case assetMissing(id: UUID)
    case exportFailed
    case uploadFailed
    case downloadFailed
    case importFailed
    case cancelled
}
