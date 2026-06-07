import Foundation

/// A playlist saved in the VaultVerse vault.
///
/// The `Playlist` is provider-neutral and long-lived. Its actual track contents
/// live in versioned `PlaylistSnapshot`s, not here — re-importing never
/// overwrites; it appends a new snapshot.
public struct Playlist: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var description: String?
    public var sourceProvider: Provider
    public var sourcePlaylistId: String?
    public var artworkURL: String?
    public var cachedArtworkPath: String?
    public var trackCount: Int
    public var originalOwnerName: String?
    public var visibility: Visibility
    public var status: PlaylistStatus
    public var importedAt: Date
    public var lastSyncedAt: Date?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        sourceProvider: Provider,
        sourcePlaylistId: String? = nil,
        artworkURL: String? = nil,
        cachedArtworkPath: String? = nil,
        trackCount: Int = 0,
        originalOwnerName: String? = nil,
        visibility: Visibility = .isPrivate,
        status: PlaylistStatus = .archived,
        importedAt: Date = Date(),
        lastSyncedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.sourceProvider = sourceProvider
        self.sourcePlaylistId = sourcePlaylistId
        self.artworkURL = artworkURL
        self.cachedArtworkPath = cachedArtworkPath
        self.trackCount = trackCount
        self.originalOwnerName = originalOwnerName
        self.visibility = visibility
        self.status = status
        self.importedAt = importedAt
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
