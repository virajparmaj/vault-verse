import Foundation

// The storage contract. Every method vends/accepts *domain structs* — persistence
// types (SwiftData @Model, a future SQL row) never leak past this seam. Services
// and the UI depend only on these protocols, so swapping in-memory ⇄ SwiftData ⇄
// cloud sync later touches nothing above.

public protocol TrackRepository: Sendable {
    func upsertTrack(_ track: Track) async throws
    func track(id: String) async throws -> Track?
    func trackByISRC(_ isrc: String) async throws -> Track?
    /// Dedup lookup: same normalized title+artist and duration within tolerance
    /// (a nil duration on either side matches on title+artist only).
    func findTrack(normalizedTitle: String, normalizedArtist: String, durationMs: Int?, toleranceMs: Int) async throws -> Track?
    func allTracks() async throws -> [Track]
}

public protocol MappingRepository: Sendable {
    func upsertMapping(_ mapping: TrackPlatformMapping) async throws
    func mappings(forTrack trackId: String) async throws -> [TrackPlatformMapping]
    func mapping(trackId: String, provider: Provider) async throws -> TrackPlatformMapping?
    func manualOverride(trackId: String, provider: Provider) async throws -> TrackPlatformMapping?
    func allMappings() async throws -> [TrackPlatformMapping]
}

public protocol PlaylistRepository: Sendable {
    func upsertPlaylist(_ playlist: Playlist) async throws
    func playlist(id: String) async throws -> Playlist?
    func playlist(provider: Provider, sourcePlaylistId: String) async throws -> Playlist?
    func allPlaylists() async throws -> [Playlist]
    func deletePlaylist(id: String) async throws
}

public protocol SnapshotRepository: Sendable {
    func insertSnapshot(_ snapshot: PlaylistSnapshot, tracks: [SnapshotTrack]) async throws
    func snapshot(id: String) async throws -> PlaylistSnapshot?
    func snapshots(forPlaylist playlistId: String) async throws -> [PlaylistSnapshot]
    func latestSnapshot(forPlaylist playlistId: String) async throws -> PlaylistSnapshot?
    /// Ordered by ascending position.
    func snapshotTracks(snapshotId: String) async throws -> [SnapshotTrack]
}

public protocol JobRepository: Sendable {
    func upsertImportJob(_ job: ImportJob) async throws
    func importJob(id: String) async throws -> ImportJob?
    func allImportJobs() async throws -> [ImportJob]

    func upsertRestoreJob(_ job: RestoreJob) async throws
    func restoreJob(id: String) async throws -> RestoreJob?
    func allRestoreJobs() async throws -> [RestoreJob]

    func upsertUnmatched(_ tracks: [UnmatchedTrack]) async throws
    func updateUnmatched(_ track: UnmatchedTrack) async throws
    func unmatched(forRestoreJob jobId: String) async throws -> [UnmatchedTrack]
}

public protocol ExportRepository: Sendable {
    func upsertExport(_ export: Export) async throws
    func allExports() async throws -> [Export]
}

public protocol ConnectedAccountRepository: Sendable {
    func upsertAccount(_ account: ConnectedAccount) async throws
    func account(provider: Provider) async throws -> ConnectedAccount?
    func allAccounts() async throws -> [ConnectedAccount]
    func deleteAccount(id: String) async throws
}

/// The aggregate store the app injects. A single implementation conforms to all
/// the focused protocols above.
public protocol VaultStore: TrackRepository, MappingRepository, PlaylistRepository,
                            SnapshotRepository, JobRepository, ExportRepository,
                            ConnectedAccountRepository {
    /// Privacy: irreversibly wipe every record in the vault.
    func deleteAllData() async throws
}
