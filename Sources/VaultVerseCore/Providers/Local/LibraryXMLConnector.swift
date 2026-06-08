import Foundation

/// A read-only Apple Music connector backed by a user's exported `Library.xml`.
///
/// This is the local-first path to a *real* library: the user runs
/// Music.app → File → Library → Export Library…, then imports the resulting `.xml`.
/// It serves that library's playlists/tracks and searches the parsed catalog, just
/// like `MockAppleMusicService` does over demo data — no network, no MusicKit,
/// no account.
///
/// It deliberately cannot write back into Apple Music (`createPlaylist`/`addTracks`
/// throw `notImplemented("write-back")`). Restore instead produces a re-importable
/// local file — see `PlaylistRestoreService.restoreToFile`.
public actor LibraryXMLConnector: MusicProviderConnector {
    public nonisolated let provider: Provider = .appleMusic

    private let profile: ProviderUserProfile
    private let libraryPlaylists: [(playlist: ProviderPlaylist, tracks: [ProviderTrack])]
    private let catalog: [ProviderTrack]

    /// Parse and load an exported library from raw file bytes. Validates the input
    /// at the boundary and throws a user-friendly `VaultVerseError` on bad files.
    public init(data: Data) throws {
        let parsed = try LibraryXMLParser.parse(data)
        self.init(parsed: parsed)
    }

    /// Build from an already-parsed library (the launch placeholder uses `.empty`).
    public init(parsed: ParsedLibrary) {
        self.profile = parsed.profile
        self.libraryPlaylists = parsed.playlists.map { (playlist: $0.playlist, tracks: $0.tracks) }
        self.catalog = parsed.catalog
    }

    // MARK: - MusicProviderConnector

    public func authenticate() async throws -> AuthSession {
        AuthSession(
            provider: .appleMusic,
            providerUserId: profile.providerUserId,
            storefront: nil,
            tokenKeychainRef: "local://library-xml"
        )
    }

    public func fetchUserProfile(auth: AuthSession) async throws -> ProviderUserProfile {
        profile
    }

    public func fetchUserPlaylists(auth: AuthSession) async throws -> [ProviderPlaylist] {
        libraryPlaylists.map(\.playlist)
    }

    public func fetchPlaylistTracks(auth: AuthSession, providerPlaylistId: String) async throws -> [ProviderTrack] {
        guard let entry = libraryPlaylists.first(where: { $0.playlist.providerPlaylistId == providerPlaylistId }) else {
            throw VaultVerseError.playlistNotFound(providerPlaylistId)
        }
        return entry.tracks
    }

    public func searchTrack(auth: AuthSession, query: TrackSearchQuery) async throws -> [ProviderTrackSearchResult] {
        // 1) Exact ISRC, when present (rare in Library.xml, but the strongest signal).
        if let isrc = query.isrc, !isrc.isEmpty {
            let hits = catalog.filter { $0.isrc?.caseInsensitiveCompare(isrc) == .orderedSame }
            if !hits.isEmpty { return hits.map(Self.result(from:)) }
        }

        // 2) Normalized title (+ artist) contains-match against the catalog.
        let qTitle = TrackNormalizer.normalizeTitle(query.title ?? "")
        guard !qTitle.isEmpty else { return [] }
        let qArtist = TrackNormalizer.normalizeArtist(query.artist ?? "")

        let hits = catalog.filter { candidate in
            let cTitle = TrackNormalizer.normalizeTitle(candidate.title)
            let cArtist = TrackNormalizer.normalizeArtist(candidate.artistName)
            let titleMatch = cTitle == qTitle || cTitle.contains(qTitle) || qTitle.contains(cTitle)
            let artistMatch = qArtist.isEmpty || cArtist == qArtist || cArtist.contains(qArtist) || qArtist.contains(cArtist)
            return titleMatch && artistMatch
        }
        return hits.map(Self.result(from:))
    }

    public func createPlaylist(auth: AuthSession, input: CreatePlaylistInput) async throws -> CreatedPlaylist {
        throw VaultVerseError.notImplemented("write-back")
    }

    public func addTracks(auth: AuthSession, providerPlaylistId: String, providerTrackIds: [String]) async throws -> AddTracksResult {
        throw VaultVerseError.notImplemented("write-back")
    }

    // MARK: - DTO mapping

    private static func result(from track: ProviderTrack) -> ProviderTrackSearchResult {
        ProviderTrackSearchResult(
            providerTrackId: track.providerTrackId,
            providerURI: track.providerURI,
            providerURL: nil,
            title: track.title,
            artistName: track.artistName,
            albumName: track.albumName,
            durationMs: track.durationMs,
            isrc: track.isrc,
            availability: track.availability
        )
    }
}
