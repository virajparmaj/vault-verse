import Foundation

/// A fully working Apple Music connector backed by bundled seed data.
///
/// It behaves like the real thing for the entire core loop: it serves library
/// playlists/tracks, searches a simulated catalog (honoring availability), and
/// "creates" playlists + "adds" tracks into an in-memory library so restore is
/// demoable end-to-end without any Apple credentials.
public actor MockAppleMusicService: MusicProviderConnector {
    public nonisolated let provider: Provider = .appleMusic

    private let profile: ProviderUserProfile
    private let libraryPlaylists: [(playlist: ProviderPlaylist, tracks: [ProviderTrack])]
    private let catalog: [ProviderTrack]
    private let latency: Duration

    // Simulated Apple Music library mutated by restore.
    private var createdPlaylists: [String: CreatedPlaylist] = [:]
    private var createdTrackIds: [String: [String]] = [:]

    /// Loads the bundled demo library.
    public init(latency: Duration = .zero) throws {
        let seed = try SeedLibrary.loadDefault()
        let model = seed.providerModel()
        self.profile = model.profile
        self.libraryPlaylists = model.playlists.map { (playlist: $0.0, tracks: $0.1) }
        let baseCatalog = Self.buildCatalog(from: model.playlists.flatMap { $0.1 })
        self.catalog = seed.applyCatalogTweaks(to: baseCatalog)
        self.latency = latency
    }

    /// Builds a connector from explicit data — used by tests for controlled cases.
    public init(
        profile: ProviderUserProfile,
        playlists: [(ProviderPlaylist, [ProviderTrack])],
        catalog: [ProviderTrack]? = nil,
        latency: Duration = .zero
    ) {
        self.profile = profile
        self.libraryPlaylists = playlists.map { (playlist: $0.0, tracks: $0.1) }
        self.catalog = catalog ?? Self.buildCatalog(from: playlists.flatMap { $0.1 })
        self.latency = latency
    }

    private static func buildCatalog(from tracks: [ProviderTrack]) -> [ProviderTrack] {
        var seen = Set<String>()
        var out: [ProviderTrack] = []
        for track in tracks where !track.isLocalOnly {
            if seen.insert(track.providerTrackId).inserted { out.append(track) }
        }
        return out
    }

    private func tick() async {
        if latency > .zero { try? await Task.sleep(for: latency) }
    }

    // MARK: - MusicProviderConnector

    public func authenticate() async throws -> AuthSession {
        await tick()
        return AuthSession(
            provider: .appleMusic,
            providerUserId: profile.providerUserId,
            storefront: profile.storefront,
            tokenKeychainRef: "mock://music-user-token"
        )
    }

    public func fetchUserProfile(auth: AuthSession) async throws -> ProviderUserProfile {
        await tick()
        return profile
    }

    public func fetchUserPlaylists(auth: AuthSession) async throws -> [ProviderPlaylist] {
        await tick()
        return libraryPlaylists.map(\.playlist)
    }

    public func fetchPlaylistTracks(auth: AuthSession, providerPlaylistId: String) async throws -> [ProviderTrack] {
        await tick()
        guard let entry = libraryPlaylists.first(where: { $0.playlist.providerPlaylistId == providerPlaylistId }) else {
            throw VaultVerseError.playlistNotFound(providerPlaylistId)
        }
        return entry.tracks
    }

    public func searchTrack(auth: AuthSession, query: TrackSearchQuery) async throws -> [ProviderTrackSearchResult] {
        await tick()

        // 1) Exact ISRC — the strongest signal.
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
        await tick()
        let id = "pl.created.\(UUID().uuidString.prefix(8))"
        let created = CreatedPlaylist(
            providerPlaylistId: id,
            name: input.name,
            url: "https://music.apple.com/library/playlist/\(id)"
        )
        createdPlaylists[id] = created
        createdTrackIds[id] = []
        return created
    }

    public func addTracks(auth: AuthSession, providerPlaylistId: String, providerTrackIds: [String]) async throws -> AddTracksResult {
        await tick()
        let existsInLibrary = libraryPlaylists.contains { $0.playlist.providerPlaylistId == providerPlaylistId }
        guard createdPlaylists[providerPlaylistId] != nil || existsInLibrary else {
            throw VaultVerseError.playlistNotFound(providerPlaylistId)
        }
        let addable = Set(catalog.filter { $0.availability == .available }.map(\.providerTrackId))
        var added: [String] = []
        var failed: [String] = []
        for id in providerTrackIds {
            if !id.isEmpty, addable.contains(id) {
                added.append(id)
            } else {
                failed.append(id)
            }
        }
        createdTrackIds[providerPlaylistId, default: []].append(contentsOf: added)
        return AddTracksResult(requested: providerTrackIds.count, added: added.count, failedProviderTrackIds: failed)
    }

    // MARK: - Test/inspection helpers

    /// Track IDs that have been added to a simulated created playlist.
    public func addedTrackIds(forCreatedPlaylist id: String) -> [String] {
        createdTrackIds[id] ?? []
    }

    private static func result(from track: ProviderTrack) -> ProviderTrackSearchResult {
        ProviderTrackSearchResult(
            providerTrackId: track.providerTrackId,
            providerURI: track.providerURI,
            providerURL: "https://music.apple.com/us/song/\(track.providerTrackId)",
            title: track.title,
            artistName: track.artistName,
            albumName: track.albumName,
            durationMs: track.durationMs,
            isrc: track.isrc,
            availability: track.availability
        )
    }
}
