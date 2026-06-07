import Foundation

/// In-memory `VaultStore` used by tests and the headless demo harness.
///
/// It is the reference implementation of the storage contract: the SwiftData
/// store must behave identically. Being an actor makes it safe to share across
/// concurrent service calls.
public actor InMemoryVaultStore: VaultStore {
    private var tracks: [String: Track] = [:]
    private var mappings: [String: TrackPlatformMapping] = [:]
    private var playlists: [String: Playlist] = [:]
    private var snapshots: [String: PlaylistSnapshot] = [:]
    private var snapshotTracksBySnapshot: [String: [SnapshotTrack]] = [:]
    private var importJobs: [String: ImportJob] = [:]
    private var restoreJobs: [String: RestoreJob] = [:]
    private var unmatched: [String: UnmatchedTrack] = [:]
    private var exports: [String: Export] = [:]
    private var accounts: [String: ConnectedAccount] = [:]

    public init() {}

    // MARK: TrackRepository

    public func upsertTrack(_ track: Track) async throws { tracks[track.id] = track }
    public func track(id: String) async throws -> Track? { tracks[id] }

    public func trackByISRC(_ isrc: String) async throws -> Track? {
        guard !isrc.isEmpty else { return nil }
        return tracks.values.first { $0.isrc?.caseInsensitiveCompare(isrc) == .orderedSame }
    }

    public func findTrack(normalizedTitle: String, normalizedArtist: String, durationMs: Int?, toleranceMs: Int) async throws -> Track? {
        tracks.values.first { candidate in
            candidate.normalizedTitle == normalizedTitle
                && candidate.normalizedArtist == normalizedArtist
                && Self.durationClose(candidate.durationMs, durationMs, toleranceMs)
        }
    }

    public func allTracks() async throws -> [Track] { Array(tracks.values) }

    private static func durationClose(_ a: Int?, _ b: Int?, _ tolerance: Int) -> Bool {
        guard let a, let b else { return true }
        return abs(a - b) <= tolerance
    }

    // MARK: MappingRepository

    public func upsertMapping(_ mapping: TrackPlatformMapping) async throws { mappings[mapping.id] = mapping }

    public func mappings(forTrack trackId: String) async throws -> [TrackPlatformMapping] {
        mappings.values.filter { $0.trackId == trackId }
    }

    public func mapping(trackId: String, provider: Provider) async throws -> TrackPlatformMapping? {
        let candidates = mappings.values.filter { $0.trackId == trackId && $0.provider == provider }
        // Manual overrides win, then highest confidence.
        return candidates.sorted {
            if $0.isManualOverride != $1.isManualOverride { return $0.isManualOverride }
            return $0.confidenceScore > $1.confidenceScore
        }.first
    }

    public func manualOverride(trackId: String, provider: Provider) async throws -> TrackPlatformMapping? {
        mappings.values.first { $0.trackId == trackId && $0.provider == provider && $0.isManualOverride }
    }

    public func allMappings() async throws -> [TrackPlatformMapping] { Array(mappings.values) }

    // MARK: PlaylistRepository

    public func upsertPlaylist(_ playlist: Playlist) async throws { playlists[playlist.id] = playlist }
    public func playlist(id: String) async throws -> Playlist? { playlists[id] }

    public func playlist(provider: Provider, sourcePlaylistId: String) async throws -> Playlist? {
        playlists.values.first { $0.sourceProvider == provider && $0.sourcePlaylistId == sourcePlaylistId }
    }

    public func allPlaylists() async throws -> [Playlist] { Array(playlists.values) }

    public func deletePlaylist(id: String) async throws {
        playlists[id] = nil
        let toRemove = snapshots.values.filter { $0.playlistId == id }.map(\.id)
        for snapshotId in toRemove {
            snapshots[snapshotId] = nil
            snapshotTracksBySnapshot[snapshotId] = nil
        }
    }

    // MARK: SnapshotRepository

    public func insertSnapshot(_ snapshot: PlaylistSnapshot, tracks: [SnapshotTrack]) async throws {
        snapshots[snapshot.id] = snapshot
        snapshotTracksBySnapshot[snapshot.id] = tracks.sorted { $0.position < $1.position }
    }

    public func snapshot(id: String) async throws -> PlaylistSnapshot? { snapshots[id] }

    public func snapshots(forPlaylist playlistId: String) async throws -> [PlaylistSnapshot] {
        snapshots.values.filter { $0.playlistId == playlistId }.sorted { $0.createdAt < $1.createdAt }
    }

    public func latestSnapshot(forPlaylist playlistId: String) async throws -> PlaylistSnapshot? {
        snapshots.values.filter { $0.playlistId == playlistId }.max { $0.createdAt < $1.createdAt }
    }

    public func snapshotTracks(snapshotId: String) async throws -> [SnapshotTrack] {
        (snapshotTracksBySnapshot[snapshotId] ?? []).sorted { $0.position < $1.position }
    }

    // MARK: JobRepository

    public func upsertImportJob(_ job: ImportJob) async throws { importJobs[job.id] = job }
    public func importJob(id: String) async throws -> ImportJob? { importJobs[id] }
    public func allImportJobs() async throws -> [ImportJob] {
        importJobs.values.sorted { $0.startedAt > $1.startedAt }
    }

    public func upsertRestoreJob(_ job: RestoreJob) async throws { restoreJobs[job.id] = job }
    public func restoreJob(id: String) async throws -> RestoreJob? { restoreJobs[id] }
    public func allRestoreJobs() async throws -> [RestoreJob] {
        restoreJobs.values.sorted { $0.startedAt > $1.startedAt }
    }

    public func upsertUnmatched(_ tracks: [UnmatchedTrack]) async throws {
        for track in tracks { unmatched[track.id] = track }
    }

    public func updateUnmatched(_ track: UnmatchedTrack) async throws { unmatched[track.id] = track }

    public func unmatched(forRestoreJob jobId: String) async throws -> [UnmatchedTrack] {
        unmatched.values.filter { $0.restoreJobId == jobId }.sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: ExportRepository

    public func upsertExport(_ export: Export) async throws { exports[export.id] = export }
    public func allExports() async throws -> [Export] {
        exports.values.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: ConnectedAccountRepository

    public func upsertAccount(_ account: ConnectedAccount) async throws { accounts[account.id] = account }
    public func account(provider: Provider) async throws -> ConnectedAccount? {
        accounts.values.first { $0.provider == provider }
    }
    public func allAccounts() async throws -> [ConnectedAccount] { Array(accounts.values) }
    public func deleteAccount(id: String) async throws { accounts[id] = nil }

    // MARK: VaultStore

    public func deleteAllData() async throws {
        tracks.removeAll()
        mappings.removeAll()
        playlists.removeAll()
        snapshots.removeAll()
        snapshotTracksBySnapshot.removeAll()
        importJobs.removeAll()
        restoreJobs.removeAll()
        unmatched.removeAll()
        exports.removeAll()
        accounts.removeAll()
    }
}
