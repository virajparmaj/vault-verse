import Foundation

/// A point-in-time, versioned capture of a playlist's contents.
///
/// Every import / re-import creates a new snapshot rather than overwriting, so a
/// user can always travel back to an older version of a playlist. The `checksum`
/// lets the import pipeline detect "no material change" between snapshots.
public struct PlaylistSnapshot: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var playlistId: String
    public var snapshotName: String?
    public var sourceProvider: Provider
    public var sourcePlaylistId: String?
    /// Playlist title captured at snapshot time — enables "title changed" diffs
    /// and self-contained archival even if the playlist is later renamed.
    public var playlistTitle: String?
    public var playlistArtworkURL: String?
    public var trackCount: Int
    public var checksum: String?
    public var changeSummary: SnapshotChangeSummary?
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        playlistId: String,
        snapshotName: String? = nil,
        sourceProvider: Provider,
        sourcePlaylistId: String? = nil,
        playlistTitle: String? = nil,
        playlistArtworkURL: String? = nil,
        trackCount: Int,
        checksum: String? = nil,
        changeSummary: SnapshotChangeSummary? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.playlistId = playlistId
        self.snapshotName = snapshotName
        self.sourceProvider = sourceProvider
        self.sourcePlaylistId = sourcePlaylistId
        self.playlistTitle = playlistTitle
        self.playlistArtworkURL = playlistArtworkURL
        self.trackCount = trackCount
        self.checksum = checksum
        self.changeSummary = changeSummary
        self.createdAt = createdAt
    }
}

/// A compact summary of what changed relative to the previous snapshot.
/// Stored on the snapshot for quick display in the timeline.
public struct SnapshotChangeSummary: Codable, Hashable, Sendable {
    public var added: Int
    public var removed: Int
    public var reordered: Int
    public var metadataChanged: Int
    public var titleChanged: Bool
    public var coverChanged: Bool
    public var note: String?

    public init(
        added: Int = 0,
        removed: Int = 0,
        reordered: Int = 0,
        metadataChanged: Int = 0,
        titleChanged: Bool = false,
        coverChanged: Bool = false,
        note: String? = nil
    ) {
        self.added = added
        self.removed = removed
        self.reordered = reordered
        self.metadataChanged = metadataChanged
        self.titleChanged = titleChanged
        self.coverChanged = coverChanged
        self.note = note
    }

    /// True when nothing materially changed since the previous snapshot.
    public var isNoMaterialChange: Bool {
        added == 0 && removed == 0 && reordered == 0 &&
        metadataChanged == 0 && !titleChanged && !coverChanged
    }
}
