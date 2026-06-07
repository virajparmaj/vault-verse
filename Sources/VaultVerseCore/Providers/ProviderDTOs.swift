import Foundation

// MARK: - Provider-neutral transfer objects
//
// These are the *wire shapes* a connector returns. They are deliberately
// separate from VaultVerse's stored domain models — the import pipeline
// normalizes DTOs into `Track`/`Playlist`/`SnapshotTrack` so nothing in the
// vault is coupled to a provider's quirks.

/// An authenticated session with a provider. In mock mode the token handle is a
/// placeholder; in live mode it references token material held in the Keychain.
public struct AuthSession: Sendable, Hashable {
    public let provider: Provider
    public let providerUserId: String?
    public let storefront: String?
    public let tokenKeychainRef: String?

    public init(provider: Provider, providerUserId: String? = nil, storefront: String? = nil, tokenKeychainRef: String? = nil) {
        self.provider = provider
        self.providerUserId = providerUserId
        self.storefront = storefront
        self.tokenKeychainRef = tokenKeychainRef
    }
}

public struct ProviderUserProfile: Sendable, Hashable {
    public let providerUserId: String
    public let displayName: String?
    public let storefront: String?

    public init(providerUserId: String, displayName: String? = nil, storefront: String? = nil) {
        self.providerUserId = providerUserId
        self.displayName = displayName
        self.storefront = storefront
    }
}

public struct ProviderPlaylist: Sendable, Hashable {
    public let providerPlaylistId: String
    public let name: String
    public let description: String?
    public let ownerName: String?
    public let artworkURL: String?
    public let isPublic: Bool
    public let trackCount: Int

    public init(providerPlaylistId: String, name: String, description: String? = nil, ownerName: String? = nil, artworkURL: String? = nil, isPublic: Bool = false, trackCount: Int = 0) {
        self.providerPlaylistId = providerPlaylistId
        self.name = name
        self.description = description
        self.ownerName = ownerName
        self.artworkURL = artworkURL
        self.isPublic = isPublic
        self.trackCount = trackCount
    }
}

public struct ProviderTrack: Sendable, Hashable {
    /// May be empty for local-only / iCloud uploads that have no catalog ID.
    public let providerTrackId: String
    public let providerURI: String?
    public let title: String
    public let artistName: String
    public let artists: [String]
    public let albumName: String?
    public let durationMs: Int?
    public let isrc: String?
    public let releaseDate: Date?
    public let explicit: Bool?
    public let artworkURL: String?
    public let addedAt: Date?
    public let availability: AvailabilityStatus
    /// Raw provider JSON for this track, retained verbatim for archival.
    public let rawPayload: String?

    public init(providerTrackId: String, providerURI: String? = nil, title: String, artistName: String, artists: [String] = [], albumName: String? = nil, durationMs: Int? = nil, isrc: String? = nil, releaseDate: Date? = nil, explicit: Bool? = nil, artworkURL: String? = nil, addedAt: Date? = nil, availability: AvailabilityStatus = .available, rawPayload: String? = nil) {
        self.providerTrackId = providerTrackId
        self.providerURI = providerURI
        self.title = title
        self.artistName = artistName
        self.artists = artists
        self.albumName = albumName
        self.durationMs = durationMs
        self.isrc = isrc
        self.releaseDate = releaseDate
        self.explicit = explicit
        self.artworkURL = artworkURL
        self.addedAt = addedAt
        self.availability = availability
        self.rawPayload = rawPayload
    }

    /// Local-only items (personal uploads / iCloud) have no catalog identity.
    public var isLocalOnly: Bool { providerTrackId.isEmpty }
}

public struct TrackSearchQuery: Sendable, Hashable {
    public let isrc: String?
    public let title: String?
    public let artist: String?
    public let album: String?
    public let durationMs: Int?
    public let storefront: String?

    public init(isrc: String? = nil, title: String? = nil, artist: String? = nil, album: String? = nil, durationMs: Int? = nil, storefront: String? = nil) {
        self.isrc = isrc
        self.title = title
        self.artist = artist
        self.album = album
        self.durationMs = durationMs
        self.storefront = storefront
    }
}

public struct ProviderTrackSearchResult: Sendable, Hashable {
    public let providerTrackId: String
    public let providerURI: String?
    public let providerURL: String?
    public let title: String
    public let artistName: String
    public let albumName: String?
    public let durationMs: Int?
    public let isrc: String?
    public let availability: AvailabilityStatus

    public init(providerTrackId: String, providerURI: String? = nil, providerURL: String? = nil, title: String, artistName: String, albumName: String? = nil, durationMs: Int? = nil, isrc: String? = nil, availability: AvailabilityStatus = .available) {
        self.providerTrackId = providerTrackId
        self.providerURI = providerURI
        self.providerURL = providerURL
        self.title = title
        self.artistName = artistName
        self.albumName = albumName
        self.durationMs = durationMs
        self.isrc = isrc
        self.availability = availability
    }
}

public struct CreatePlaylistInput: Sendable, Hashable {
    public let name: String
    public let description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

public struct CreatedPlaylist: Sendable, Hashable {
    public let providerPlaylistId: String
    public let name: String
    public let url: String?

    public init(providerPlaylistId: String, name: String, url: String? = nil) {
        self.providerPlaylistId = providerPlaylistId
        self.name = name
        self.url = url
    }
}

public struct AddTracksResult: Sendable, Hashable {
    public let requested: Int
    public let added: Int
    public let failedProviderTrackIds: [String]

    public init(requested: Int, added: Int, failedProviderTrackIds: [String] = []) {
        self.requested = requested
        self.added = added
        self.failedProviderTrackIds = failedProviderTrackIds
    }
}
