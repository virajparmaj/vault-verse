import Foundation

/// Real Apple Music connector — intentionally stubbed for the first pass.
///
/// Every method throws `providerNotConfigured` / `notImplemented` so the app can
/// select it without crashing, while the wiring points are documented inline.
///
/// ## Two live paths (pick one when implementing)
///
/// **A. MusicKit framework (recommended for a native macOS app).**
/// Add the *MusicKit* capability to the app target, then:
///   - Authorize:  `await MusicAuthorization.request()` → `.authorized`.
///   - Profile/storefront: `try await MusicDataRequest` to `…/me/storefront`.
///   - Library playlists: `MusicLibraryRequest<Playlist>()`.
///   - Playlist tracks:   load `playlist.tracks` relationship.
///   - Catalog search:    `MusicCatalogSearchRequest(term:, types: [Song.self])`,
///                        prefer filtering by ISRC where possible.
///   - Create playlist:   `MusicLibrary.shared.createPlaylist(name:description:)`.
///   - Add tracks:        `MusicLibrary.shared.add(_:to:)`.
/// MusicKit manages the developer token for a properly provisioned app, so the
/// `.p8`/Team ID/Key ID below are not strictly needed on this path.
///
/// **B. Apple Music REST API (server-style).**
///   - Developer token: ES256 JWT signed with the `.p8` (header `kid` = Key ID,
///     payload `iss` = Team ID, `iat`/`exp` ≤ 6 months). Sign server-side; never
///     ship the `.p8` in the app.
///   - Music User Token: obtained via MusicKit JS / native authorization; store
///     it in the Keychain (see `KeychainStore`).
///   - Requests: `Authorization: Bearer <developerToken>`,
///     `Music-User-Token: <userToken>` against `https://api.music.apple.com/v1/…`.
///     Library: `/v1/me/library/playlists`; catalog search:
///     `/v1/catalog/{storefront}/search?types=songs&filter[isrc]=…`.
///
/// Both paths must: respect storefront/region availability, batch `addTracks`,
/// back off on HTTP 429, and surface per-track failures (never throw on the
/// first bad track).
public struct LiveAppleMusicService: MusicProviderConnector {
    public let provider: Provider = .appleMusic
    public let config: AppleMusicConfig

    public init(config: AppleMusicConfig = .unconfigured) {
        self.config = config
    }

    private func ensureConfigured() throws {
        guard config.isConfigured else { throw VaultVerseError.providerNotConfigured(.appleMusic) }
    }

    public func authenticate() async throws -> AuthSession {
        try ensureConfigured()
        // TODO(live): MusicAuthorization.request() (path A) OR mint developer token
        // from .p8 and acquire a Music User Token (path B); persist token via Keychain.
        throw VaultVerseError.notImplemented("Apple Music live authentication")
    }

    public func fetchUserProfile(auth: AuthSession) async throws -> ProviderUserProfile {
        try ensureConfigured()
        // TODO(live): GET /v1/me/storefront (REST) or MusicKit storefront API.
        throw VaultVerseError.notImplemented("Apple Music live profile fetch")
    }

    public func fetchUserPlaylists(auth: AuthSession) async throws -> [ProviderPlaylist] {
        try ensureConfigured()
        // TODO(live): MusicLibraryRequest<Playlist>() or GET /v1/me/library/playlists (paginated).
        throw VaultVerseError.notImplemented("Apple Music live playlist fetch")
    }

    public func fetchPlaylistTracks(auth: AuthSession, providerPlaylistId: String) async throws -> [ProviderTrack] {
        try ensureConfigured()
        // TODO(live): load playlist.tracks relationship or
        // GET /v1/me/library/playlists/{id}/tracks (paginated); map to ProviderTrack.
        throw VaultVerseError.notImplemented("Apple Music live track fetch")
    }

    public func searchTrack(auth: AuthSession, query: TrackSearchQuery) async throws -> [ProviderTrackSearchResult] {
        try ensureConfigured()
        // TODO(live): catalog search by ISRC first, then term; respect storefront.
        throw VaultVerseError.notImplemented("Apple Music live catalog search")
    }

    public func createPlaylist(auth: AuthSession, input: CreatePlaylistInput) async throws -> CreatedPlaylist {
        try ensureConfigured()
        // TODO(live): MusicLibrary.shared.createPlaylist(...) or POST /v1/me/library/playlists.
        throw VaultVerseError.notImplemented("Apple Music live playlist creation")
    }

    public func addTracks(auth: AuthSession, providerPlaylistId: String, providerTrackIds: [String]) async throws -> AddTracksResult {
        try ensureConfigured()
        // TODO(live): batch add (chunks of ~100), retry on 429, collect per-track failures.
        throw VaultVerseError.notImplemented("Apple Music live track insertion")
    }
}
