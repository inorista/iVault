//
//  LoginSecret.swift
//  iVault
//
//  Created by Tu on 27/7/26.
//

import Foundation

/// The decrypted login payload for a vault entry.
nonisolated struct LoginSecret: Codable, Equatable, Sendable {
    let title: String
    let username: String
    let password: String
    let website: String?
    let notes: String?
}
