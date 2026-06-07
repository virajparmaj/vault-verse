import Foundation

/// A music platform VaultVerse can archive from / restore to.
///
/// Only `appleMusic` is wired in the first pass; the others exist so the data
/// model and connector abstraction are ready for them without migration.
public enum Provider: String, Codable, Sendable, Hashable, CaseIterable {
    case appleMusic = "apple_music"
    case spotify = "spotify"
    case youtubeMusic = "youtube_music"

    public var displayName: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        case .youtubeMusic: return "YouTube Music"
        }
    }
}

/// Lifecycle status shared by import and restore jobs.
public enum JobStatus: String, Codable, Sendable, Hashable {
    case pending
    case running
    case succeeded
    /// Completed but at least one playlist/track failed or needs review.
    case partial
    case failed
    case cancelled
}

/// How a track was matched to a provider catalog entry. Ordered loosely by
/// descending confidence; see `TrackMatchingService` for the scoring ladder.
public enum MatchMethod: String, Codable, Sendable, Hashable {
    case isrc
    case titleArtistDuration = "title_artist_duration"
    case titleArtistAlbum = "title_artist_album"
    case titleArtistDurationClose = "title_artist_duration_close"
    case fuzzy
    case manual
    case none
}

/// Whether a mapped track can actually be played/added in the target catalog.
public enum AvailabilityStatus: String, Codable, Sendable, Hashable {
    case available
    case regionUnavailable = "region_unavailable"
    case notFound = "not_found"
    case unknown
}

/// Playlist visibility carried over from the source platform.
public enum Visibility: String, Codable, Sendable, Hashable {
    case isPrivate = "private"
    case isPublic = "public"
    case shared
}

/// Where a saved playlist currently stands in VaultVerse.
public enum PlaylistStatus: String, Codable, Sendable, Hashable {
    case archived
    case importing
    case error
}

/// Supported backup export formats. `m3u` is reserved for a later pass.
public enum ExportFormat: String, Codable, Sendable, Hashable, CaseIterable {
    case json
    case csv
    case m3u
}
