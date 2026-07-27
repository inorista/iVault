//
//  VaultPayload.swift
//  iVault
//
//  Created by Tu on 27/7/26.
//

import Foundation

/// A versioned, decrypted payload stored by one vault entry.
///
/// Its encoded representation always contains a schema version, a kind
/// discriminator, and exactly one matching payload.
enum VaultPayload: Equatable, Sendable {
    static let currentSchemaVersion = 1

    case login(LoginSecret)
    case secureNote(SecureNote)
    case image(SecureImage)

    var kind: VaultItemKind {
        switch self {
        case .login:
            .login
        case .secureNote:
            .secureNote
        case .image:
            .image
        }
    }
}

extension VaultPayload: Codable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(
            Int.self,
            forKey: .schemaVersion
        )

        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported vault payload schema version: \(schemaVersion)."
            )
        }

        let kind = try container.decode(
            VaultItemKind.self,
            forKey: .kind
        )

        switch kind {
        case .login:
            self = .login(
                try container.decode(
                    LoginSecret.self,
                    forKey: .data
                )
            )
        case .secureNote:
            self = .secureNote(
                try container.decode(
                    SecureNote.self,
                    forKey: .data
                )
            )
        case .image:
            self = .image(
                try container.decode(
                    SecureImage.self,
                    forKey: .data
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(
            Self.currentSchemaVersion,
            forKey: .schemaVersion
        )
        try container.encode(kind, forKey: .kind)

        switch self {
        case .login(let login):
            try container.encode(login, forKey: .data)
        case .secureNote(let note):
            try container.encode(note, forKey: .data)
        case .image(let image):
            try container.encode(image, forKey: .data)
        }
    }
}
