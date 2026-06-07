import Foundation

/// A track's membership in a specific snapshot, including its exact position.
///
/// Order matters — restoring a playlist must reproduce the original sequence —
/// so `position` is authoritative and unique within a snapshot. The untouched
/// provider payload is retained for debugging and worst-case manual rebuilds.
public struct SnapshotTrack: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var snapshotId: String
    public var trackId: String
    public var position: Int
    // Denormalized metadata captured at snapshot time. Lets a snapshot be diffed
    // and reconstructed on its own, even if the shared Track row changes later.
    public var title: String
    public var artistName: String
    public var albumName: String?
    public var durationMs: Int?
    public var addedAtSource: Date?
    public var addedBySource: String?
    public var sourceProviderTrackId: String?
    public var sourceProviderURI: String?
    /// Raw provider JSON for this track, kept verbatim for archival/debugging.
    public var rawSourcePayload: String?
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        snapshotId: String,
        trackId: String,
        position: Int,
        title: String,
        artistName: String,
        albumName: String? = nil,
        durationMs: Int? = nil,
        addedAtSource: Date? = nil,
        addedBySource: String? = nil,
        sourceProviderTrackId: String? = nil,
        sourceProviderURI: String? = nil,
        rawSourcePayload: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.snapshotId = snapshotId
        self.trackId = trackId
        self.position = position
        self.title = title
        self.artistName = artistName
        self.albumName = albumName
        self.durationMs = durationMs
        self.addedAtSource = addedAtSource
        self.addedBySource = addedBySource
        self.sourceProviderTrackId = sourceProviderTrackId
        self.sourceProviderURI = sourceProviderURI
        self.rawSourcePayload = rawSourcePayload
        self.createdAt = createdAt
    }
}
