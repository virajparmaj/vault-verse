import Foundation
#if canImport(MusicKit)
import MusicKit
#endif

/// Live Apple Music connector powered by MusicKit.
///
/// **Deferred, opt-in, paid-only.** VaultVerse is local-first by default
/// (`MockAppleMusicService` demo data + `LibraryXMLConnector` for real libraries).
/// This connector stays compiled but is never the default: enabling it needs the
/// MusicKit capability, which requires a paid Apple Developer membership and a
/// provisioning profile with the MusicKit service. Construct it explicitly only
/// once those are in place.
///
/// Uses MusicKit's `MusicAuthorization` for the system permission prompt and
/// `MusicDataRequest` for all API calls (it adds the developer token and music
/// user token automatically — no `.p8` / JWT management needed for a native app).
///
/// When MusicKit is unavailable (pure SPM / CI / no entitlement), every method
/// throws `providerNotConfigured` so the app stays usable on the local connectors.
public struct LiveAppleMusicService: MusicProviderConnector {
    public let provider: Provider = .appleMusic

    public init() {}

    // MARK: - API base

    private static let apiBase = "https://api.music.apple.com/v1"

    // ╔══════════════════════════════════════════════════════════════════════╗
    // ║  MusicKit-backed implementation (Xcode builds)                     ║
    // ╚══════════════════════════════════════════════════════════════════════╝
    #if canImport(MusicKit)

    // MARK: - Authentication

    public func authenticate() async throws -> AuthSession {
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            throw VaultVerseError.authorizationDenied(.appleMusic)
        }
        let storefront = await resolveStorefront()
        return AuthSession(
            provider: .appleMusic,
            storefront: storefront,
            tokenKeychainRef: "musickit://authorized"
        )
    }

    // MARK: - Profile

    public func fetchUserProfile(auth: AuthSession) async throws -> ProviderUserProfile {
        let name = NSFullUserName().isEmpty ? NSUserName() : NSFullUserName()
        return ProviderUserProfile(
            providerUserId: "musickit-local-user",
            displayName: name.isEmpty ? "Apple Music user" : name,
            storefront: auth.storefront
        )
    }

    // MARK: - Playlists (paginated)

    public func fetchUserPlaylists(auth: AuthSession) async throws -> [ProviderPlaylist] {
        var result: [ProviderPlaylist] = []
        var nextPath: String? = "/me/library/playlists?limit=100"

        while let path = nextPath {
            let data = try await apiGet(path)
            let page = try decodeJSON(AMPagedResponse<AMLibraryPlaylist>.self, from: data)
            for item in page.data {
                let a = item.attributes
                result.append(ProviderPlaylist(
                    providerPlaylistId: item.id,
                    name: a.name,
                    description: a.descriptionText?.standard,
                    artworkURL: a.artwork?.artworkURL(size: 600),
                    trackCount: a.trackCount ?? 0
                ))
            }
            nextPath = page.next
        }
        return result
    }

    // MARK: - Tracks (paginated + ISRC enrichment)

    public func fetchPlaylistTracks(auth: AuthSession, providerPlaylistId: String) async throws -> [ProviderTrack] {
        let storefront = auth.storefront ?? "us"
        var allTracks: [AMLibraryTrack] = []
        var nextPath: String? = "/me/library/playlists/\(providerPlaylistId)/tracks?limit=100"

        while let path = nextPath {
            let data = try await apiGet(path)
            let page = try decodeJSON(AMPagedResponse<AMLibraryTrack>.self, from: data)
            allTracks.append(contentsOf: page.data)
            nextPath = page.next
        }

        // Batch-fetch ISRCs from catalog for better dedup accuracy
        let catalogIds = allTracks.compactMap { $0.attributes.playParams?.catalogId }
        let isrcMap = await batchFetchISRCs(catalogIds: catalogIds, storefront: storefront)

        let dateFormatter = ISO8601DateFormatter()
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = TimeZone(identifier: "UTC")

        return allTracks.map { track in
            let a = track.attributes
            let catalogId = a.playParams?.catalogId ?? ""
            return ProviderTrack(
                providerTrackId: catalogId,
                providerURI: catalogId.isEmpty ? nil : "music://song/\(catalogId)",
                title: a.name,
                artistName: a.artistName,
                artists: [a.artistName],
                albumName: a.albumName,
                durationMs: a.durationInMillis,
                isrc: isrcMap[catalogId],
                releaseDate: a.releaseDate.flatMap { dayFormatter.date(from: $0) },
                explicit: a.contentRating == "explicit",
                artworkURL: a.artwork?.artworkURL(size: 600),
                addedAt: a.dateAdded.flatMap { dateFormatter.date(from: $0) },
                availability: .available
            )
        }
    }

    // MARK: - Catalog search

    public func searchTrack(auth: AuthSession, query: TrackSearchQuery) async throws -> [ProviderTrackSearchResult] {
        let storefront = auth.storefront ?? query.storefront ?? "us"

        // 1. ISRC search — highest precision
        if let isrc = query.isrc, !isrc.isEmpty {
            let results = try await searchByISRC(isrc, storefront: storefront)
            if !results.isEmpty { return results }
        }

        // 2. Term search — broader
        let term = [query.title, query.artist].compactMap { $0 }.joined(separator: " ")
        guard !term.isEmpty else { return [] }

        let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term
        let data = try await apiGet("/catalog/\(storefront)/search?types=songs&limit=10&term=\(encoded)")
        let search = try decodeJSON(AMSearchResponse.self, from: data)

        return (search.results.songs?.data ?? []).map(catalogSongToResult)
    }

    // MARK: - Create playlist

    public func createPlaylist(auth: AuthSession, input: CreatePlaylistInput) async throws -> CreatedPlaylist {
        struct Body: Encodable {
            struct Attributes: Encodable {
                let name: String
                let description: String?
            }
            let attributes: Attributes
        }
        let body = Body(attributes: .init(name: input.name, description: input.description))
        let data = try await apiPost("/me/library/playlists", body: body)
        let page = try decodeJSON(AMPagedResponse<AMLibraryPlaylist>.self, from: data)

        guard let first = page.data.first else {
            throw VaultVerseError.invalidInput("Apple Music did not return the created playlist.")
        }
        return CreatedPlaylist(
            providerPlaylistId: first.id,
            name: first.attributes.name,
            url: "https://music.apple.com/library/playlist/\(first.id)"
        )
    }

    // MARK: - Add tracks (batched)

    public func addTracks(auth: AuthSession, providerPlaylistId: String, providerTrackIds: [String]) async throws -> AddTracksResult {
        let validIds = providerTrackIds.filter { !$0.isEmpty }
        let skipped = providerTrackIds.count - validIds.count
        var totalAdded = 0
        var failedIds: [String] = Array(repeating: "", count: skipped)

        for chunk in validIds.chunked(maxSize: 100) {
            do {
                try await addTracksChunk(playlistId: providerPlaylistId, trackIds: chunk)
                totalAdded += chunk.count
            } catch {
                failedIds.append(contentsOf: chunk)
            }
        }
        return AddTracksResult(
            requested: providerTrackIds.count,
            added: totalAdded,
            failedProviderTrackIds: failedIds
        )
    }

    // MARK: - Private: API transport

    private func apiGet(_ path: String) async throws -> Data {
        let urlString = path.hasPrefix("http") ? path : "\(Self.apiBase)\(path)"
        guard let url = URL(string: urlString) else {
            throw VaultVerseError.invalidInput("Bad Apple Music API URL: \(path)")
        }
        let request = MusicDataRequest(urlRequest: URLRequest(url: url))
        let response = try await request.response()
        return response.data
    }

    private func apiPost(_ path: String, body: some Encodable) async throws -> Data {
        guard let url = URL(string: "\(Self.apiBase)\(path)") else {
            throw VaultVerseError.invalidInput("Bad Apple Music API URL: \(path)")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(body)
        let request = MusicDataRequest(urlRequest: urlRequest)
        let response = try await request.response()
        return response.data
    }

    // MARK: - Private: storefront

    private func resolveStorefront() async -> String {
        do {
            let data = try await apiGet("/me/storefront")
            struct SFResponse: Decodable {
                struct SF: Decodable { let id: String }
                let data: [SF]
            }
            let decoded = try decodeJSON(SFResponse.self, from: data)
            if let id = decoded.data.first?.id { return id }
        } catch {}
        return Locale.current.region?.identifier.lowercased() ?? "us"
    }

    // MARK: - Private: ISRC enrichment

    private func batchFetchISRCs(catalogIds: [String], storefront: String) async -> [String: String] {
        let uniqueIds = Array(Set(catalogIds.filter { !$0.isEmpty }))
        guard !uniqueIds.isEmpty else { return [:] }
        var map: [String: String] = [:]

        for chunk in uniqueIds.chunked(maxSize: 300) {
            let ids = chunk.joined(separator: ",")
            do {
                let data = try await apiGet("/catalog/\(storefront)/songs?ids=\(ids)")
                let page = try decodeJSON(AMPagedResponse<AMCatalogSong>.self, from: data)
                for song in page.data {
                    if let isrc = song.attributes.isrc { map[song.id] = isrc }
                }
            } catch {
                continue   // Non-fatal: ISRCs are a dedup bonus, not critical
            }
        }
        return map
    }

    // MARK: - Private: ISRC search

    private func searchByISRC(_ isrc: String, storefront: String) async throws -> [ProviderTrackSearchResult] {
        let data = try await apiGet("/catalog/\(storefront)/songs?filter[isrc]=\(isrc)")
        let page = try decodeJSON(AMPagedResponse<AMCatalogSong>.self, from: data)
        return page.data.map(catalogSongToResult)
    }

    // MARK: - Private: add-tracks chunk

    private func addTracksChunk(playlistId: String, trackIds: [String]) async throws {
        struct Body: Encodable {
            struct TrackRef: Encodable { let id: String; let type: String }
            let data: [TrackRef]
        }
        let body = Body(data: trackIds.map { Body.TrackRef(id: $0, type: "songs") })
        let _ = try await apiPost("/me/library/playlists/\(playlistId)/tracks", body: body)
    }

    // MARK: - Private: DTO mapping

    private func catalogSongToResult(_ song: AMCatalogSong) -> ProviderTrackSearchResult {
        let a = song.attributes
        return ProviderTrackSearchResult(
            providerTrackId: song.id,
            providerURI: "music://song/\(song.id)",
            providerURL: a.url,
            title: a.name,
            artistName: a.artistName,
            albumName: a.albumName,
            durationMs: a.durationInMillis,
            isrc: a.isrc,
            availability: .available
        )
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw VaultVerseError.decodingFailed("Apple Music API: \(error.localizedDescription)")
        }
    }

    // ╔══════════════════════════════════════════════════════════════════════╗
    // ║  Inert (no MusicKit: pure SPM / CI / entitlement absent)           ║
    // ╚══════════════════════════════════════════════════════════════════════╝
    //
    // Without the MusicKit framework + capability there is nothing to talk to, so
    // every method reports `providerNotConfigured`. The app never selects this
    // connector by default; it's opt-in once a paid membership is in place.
    #else

    public func authenticate() async throws -> AuthSession {
        throw VaultVerseError.providerNotConfigured(.appleMusic)
    }
    public func fetchUserProfile(auth: AuthSession) async throws -> ProviderUserProfile {
        throw VaultVerseError.providerNotConfigured(.appleMusic)
    }
    public func fetchUserPlaylists(auth: AuthSession) async throws -> [ProviderPlaylist] {
        throw VaultVerseError.providerNotConfigured(.appleMusic)
    }
    public func fetchPlaylistTracks(auth: AuthSession, providerPlaylistId: String) async throws -> [ProviderTrack] {
        throw VaultVerseError.providerNotConfigured(.appleMusic)
    }
    public func searchTrack(auth: AuthSession, query: TrackSearchQuery) async throws -> [ProviderTrackSearchResult] {
        throw VaultVerseError.providerNotConfigured(.appleMusic)
    }
    public func createPlaylist(auth: AuthSession, input: CreatePlaylistInput) async throws -> CreatedPlaylist {
        throw VaultVerseError.providerNotConfigured(.appleMusic)
    }
    public func addTracks(auth: AuthSession, providerPlaylistId: String, providerTrackIds: [String]) async throws -> AddTracksResult {
        throw VaultVerseError.providerNotConfigured(.appleMusic)
    }

    #endif
}

// MARK: - Apple Music API JSON models (provider-private)
//
// These mirror the Apple Music API response shapes for JSON decoding only.
// They're intentionally separate from VaultVerse's domain models.

private struct AMPagedResponse<T: Decodable>: Decodable {
    let data: [T]
    let next: String?
}

private struct AMLibraryPlaylist: Decodable {
    let id: String
    let attributes: Attributes

    struct Attributes: Decodable {
        let name: String
        let descriptionText: Description?
        let artwork: AMArtwork?
        let trackCount: Int?
        let dateAdded: String?

        struct Description: Decodable {
            let standard: String?
        }

        enum CodingKeys: String, CodingKey {
            case name
            case descriptionText = "description"
            case artwork
            case trackCount
            case dateAdded
        }
    }
}

private struct AMLibraryTrack: Decodable {
    let id: String
    let attributes: Attributes

    struct Attributes: Decodable {
        let name: String
        let artistName: String
        let albumName: String?
        let durationInMillis: Int?
        let artwork: AMArtwork?
        let contentRating: String?
        let releaseDate: String?
        let dateAdded: String?
        let playParams: PlayParams?

        struct PlayParams: Decodable {
            let catalogId: String?
        }
    }
}

private struct AMCatalogSong: Decodable {
    let id: String
    let attributes: Attributes

    struct Attributes: Decodable {
        let name: String
        let artistName: String
        let albumName: String?
        let durationInMillis: Int?
        let isrc: String?
        let artwork: AMArtwork?
        let url: String?
        let contentRating: String?
    }
}

private struct AMSearchResponse: Decodable {
    let results: Results

    struct Results: Decodable {
        let songs: AMPagedResponse<AMCatalogSong>?
    }
}

private struct AMArtwork: Decodable {
    let url: String?
    let width: Int?
    let height: Int?

    /// Apple Music artwork URLs use `{w}` and `{h}` placeholders.
    func artworkURL(size: Int) -> String? {
        url?.replacingOccurrences(of: "{w}", with: "\(size)")
           .replacingOccurrences(of: "{h}", with: "\(size)")
    }
}

// MARK: - Array chunking helper

private extension Array {
    func chunked(maxSize: Int) -> [[Element]] {
        stride(from: 0, to: count, by: maxSize).map {
            Array(self[$0 ..< Swift.min($0 + maxSize, count)])
        }
    }
}
