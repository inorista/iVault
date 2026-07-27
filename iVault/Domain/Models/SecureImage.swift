import Foundation

/// The decrypted metadata that points to an encrypted image asset.
struct SecureImage: Codable, Equatable, Sendable {
    let title: String
    let assetID: UUID
    let originalFilename: String?
    let mediaType: String?
    let byteCount: Int64
    let notes: String?
}

/// Editable image values that exist only while the editor is active.
struct SecureImageDraft: Equatable, Sendable {
    var title: String
    var imageData: Data?
    var originalFilename: String?
    var mediaType: String?
    var notes: String

    init(
        title: String = "",
        imageData: Data? = nil,
        originalFilename: String? = nil,
        mediaType: String? = nil,
        notes: String = ""
    ) {
        self.title = title
        self.imageData = imageData
        self.originalFilename = originalFilename
        self.mediaType = mediaType
        self.notes = notes
    }
}
