import Foundation

/// The single abstraction every music platform plugs into.
///
/// This is the seam that lets VaultVerse keep one neutral internal format while
/// supporting many providers. The first pass ships `MockAppleMusicService` and a
/// `LiveAppleMusicService` stub; Spotify/YouTube conform later without touching
/// the services or UI above.
public protocol MusicProviderConnector: Sendable {
    var provider: Provider { get }

    /// Establish (or restore) an authenticated session.
    func authenticate() async throws -> AuthSession

    func fetchUserProfile(auth: AuthSession) async throws -> ProviderUserProfile

    func fetchUserPlaylists(auth: AuthSession) async throws -> [ProviderPlaylist]

    func fetchPlaylistTracks(auth: AuthSession, providerPlaylistId: String) async throws -> [ProviderTrack]

    /// Search the provider's *catalog* for a track (used during restore matching).
    func searchTrack(auth: AuthSession, query: TrackSearchQuery) async throws -> [ProviderTrackSearchResult]

    /// Create a new (empty) playlist in the user's library.
    func createPlaylist(auth: AuthSession, input: CreatePlaylistInput) async throws -> CreatedPlaylist

    /// Add catalog tracks, in order, to a playlist. Implementations should batch
    /// and report per-track failures rather than throwing on the first problem.
    func addTracks(auth: AuthSession, providerPlaylistId: String, providerTrackIds: [String]) async throws -> AddTracksResult
}
