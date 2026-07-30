//
//  VaultError.swift
//  iVault
//
//  Created by Tu on 27/7/26.
//

import Foundation

/// A field that can fail validation before a vault entry is saved.
nonisolated enum VaultField: String, Equatable, Sendable {
    case title
    case password
    case noteBody
    case imageData
}

/// A validation failure for a vault draft.
nonisolated enum VaultValidationError: Error, Equatable, Sendable {
    case requiredField(VaultField)
    case invalidWebsite
    case imageExceedsSizeLimit(maximumBytes: Int64)
}

/// A domain-level failure while accessing or changing the vault.
///
/// Framework-specific errors such as `OSStatus`, SwiftData errors, and
/// cryptographic errors are mapped to this type at the service boundary.
nonisolated enum VaultError: Error, Equatable, Sendable {
    case locked
    case itemNotFound(id: UUID)
    case assetNotFound(id: UUID)
    case invalidDraft(VaultValidationError)
    case unsupportedPayloadVersion(Int)
    case corruptedPayload
    case keyUnavailable
    case authenticationCancelled
    case authenticationFailed
    case storageUnavailable
    case operationFailed
}
