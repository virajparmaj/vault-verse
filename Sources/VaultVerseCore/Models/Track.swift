import Foundation

/// A normalized, provider-neutral song.
///
/// This is the *canonical identity* of a song inside VaultVerse. Provider-specific
/// IDs (Apple Music, Spotify, …) never live here — they live in
/// `TrackPlatformMapping`. The same song keeps one `Track` and accumulates
/// mappings across platforms over time (the "cross-platform passport").
public struct Track: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var normalizedTitle: String
    public var primaryArtist: String
    public var artists: [String]
    public var normalizedArtist: String
    public var album: String?
    public var durationMs: Int?
    public var isrc: String?
    public var releaseDate: Date?
    public var explicit: Bool?
    public var artworkURL: String?
    public var previewURL: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        normalizedTitle: String,
        primaryArtist: String,
        artists: [String],
        normalizedArtist: String,
        album: String? = nil,
        durationMs: Int? = nil,
        isrc: String? = nil,
        releaseDate: Date? = nil,
        explicit: Bool? = nil,
        artworkURL: String? = nil,
        previewURL: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.normalizedTitle = normalizedTitle
        self.primaryArtist = primaryArtist
        self.artists = artists
        self.normalizedArtist = normalizedArtist
        self.album = album
        self.durationMs = durationMs
        self.isrc = isrc
        self.releaseDate = releaseDate
        self.explicit = explicit
        self.artworkURL = artworkURL
        self.previewURL = previewURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
