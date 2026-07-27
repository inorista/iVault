//
//  SecureNote.swift
//  iVault
//
//  Created by Tu on 27/7/26.
//

import Foundation

/// The decrypted secure-note payload for a vault entry.
struct SecureNote: Codable, Equatable, Sendable {
    let title: String
    let body: String
}

/// Editable secure-note values that exist only while the editor is active.
struct SecureNoteDraft: Equatable, Sendable {
    var title: String
    var body: String

    init(
        title: String = "",
        body: String = ""
    ) {
        self.title = title
        self.body = body
    }
}
