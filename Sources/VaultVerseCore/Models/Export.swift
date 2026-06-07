import Foundation

/// A generated backup file (JSON/CSV) recorded in the vault for reference.
public struct Export: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var playlistId: String?
    public var snapshotId: String?
    public var format: ExportFormat
    /// Local file URL string where the export was written.
    public var fileURL: String?
    public var byteCount: Int?
    public let createdAt: Date
    public var expiresAt: Date?

    public init(
        id: String = UUID().uuidString,
        playlistId: String? = nil,
        snapshotId: String? = nil,
        format: ExportFormat,
        fileURL: String? = nil,
        byteCount: Int? = nil,
        createdAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.playlistId = playlistId
        self.snapshotId = snapshotId
        self.format = format
        self.fileURL = fileURL
        self.byteCount = byteCount
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}
