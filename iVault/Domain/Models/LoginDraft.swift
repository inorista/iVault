//
//  LoginDraft.swift
//  iVault
//
//  Created by Tu on 27/7/26.
//

import Foundation

/// Editable login values that exist only while the editor is active.
nonisolated struct LoginDraft: Equatable, Sendable {
    var title: String
    var username: String
    var password: String
    var website: String
    var notes: String

    init(
        title: String = "",
        username: String = "",
        password: String = "",
        website: String = "",
        notes: String = ""
    ) {
        self.title = title
        self.username = username
        self.password = password
        self.website = website
        self.notes = notes
    }
}
