import Foundation
import SwiftData
import VaultVerseCore

/// SwiftData-backed implementation of the `VaultStore` contract.
///
/// `@ModelActor` gives this its own actor-isolated `ModelContext`, so it is safe
/// to share across concurrent service calls. Queries fetch-and-filter in Swift
/// (data volume is small for a single user) — behavior matches `InMemoryVaultStore`,
/// which is the reference implementation exercised by the test suite.
@ModelActor
actor SwiftDataVaultStore: VaultStore {

    // MARK: - Generic helpers

    private func fetchAll<T: PersistentModel>(_ type: T.Type) throws -> [T] {
        try modelContext.fetch(FetchDescriptor<T>())
    }

    private func persist() throws {
        if modelContext.hasChanges { try modelContext.save() }
    }

    private static func close(_ a: Int?, _ b: Int?, _ tolerance: Int) -> Bool {
        guard let a, let b else { return true }
        return abs(a - b) <= tolerance
    }

    // MARK: - TrackRepository

    func upsertTrack(_ track: Track) async throws {
        if let existing = try fetchAll(SDTrack.self).first(where: { $0.id == track.id }) {
            existing.apply(track)
        } else {
            modelContext.insert(SDTrack(track))
        }
        try persist()
    }

    func track(id: String) async throws -> Track? {
        try fetchAll(SDTrack.self).first { $0.id == id }?.toDomain()
    }

    func trackByISRC(_ isrc: String) async throws -> Track? {
        guard !isrc.isEmpty else { return nil }
        return try fetchAll(SDTrack.self).first { $0.isrc?.caseInsensitiveCompare(isrc) == .orderedSame }?.toDomain()
    }

    func findTrack(normalizedTitle: String, normalizedArtist: String, durationMs: Int?, toleranceMs: Int) async throws -> Track? {
        try fetchAll(SDTrack.self).first { candidate in
            candidate.normalizedTitle == normalizedTitle
                && candidate.normalizedArtist == normalizedArtist
                && Self.close(candidate.durationMs, durationMs, toleranceMs)
        }?.toDomain()
    }

    func allTracks() async throws -> [Track] {
        try fetchAll(SDTrack.self).map { $0.toDomain() }
    }

    // MARK: - MappingRepository

    func upsertMapping(_ mapping: TrackPlatformMapping) async throws {
        if let existing = try fetchAll(SDMapping.self).first(where: { $0.id == mapping.id }) {
            modelContext.delete(existing)
        }
        modelContext.insert(SDMapping(mapping))
        try persist()
    }

    func mappings(forTrack trackId: String) async throws -> [TrackPlatformMapping] {
        try fetchAll(SDMapping.self).filter { $0.trackId == trackId }.map { $0.toDomain() }
    }

    func mapping(trackId: String, provider: Provider) async throws -> TrackPlatformMapping? {
        let candidates = try fetchAll(SDMapping.self).filter { $0.trackId == trackId && $0.provider == provider.rawValue }
        return candidates.sorted {
            if $0.isManualOverride != $1.isManualOverride { return $0.isManualOverride }
            return $0.confidenceScore > $1.confidenceScore
        }.first?.toDomain()
    }

    func manualOverride(trackId: String, provider: Provider) async throws -> TrackPlatformMapping? {
        try fetchAll(SDMapping.self)
            .first { $0.trackId == trackId && $0.provider == provider.rawValue && $0.isManualOverride }?
            .toDomain()
    }

    func allMappings() async throws -> [TrackPlatformMapping] {
        try fetchAll(SDMapping.self).map { $0.toDomain() }
    }

    // MARK: - PlaylistRepository

    func upsertPlaylist(_ playlist: Playlist) async throws {
        if let existing = try fetchAll(SDPlaylist.self).first(where: { $0.id == playlist.id }) {
            existing.apply(playlist)
        } else {
            modelContext.insert(SDPlaylist(playlist))
        }
        try persist()
    }

    func playlist(id: String) async throws -> Playlist? {
        try fetchAll(SDPlaylist.self).first { $0.id == id }?.toDomain()
    }

    func playlist(provider: Provider, sourcePlaylistId: String) async throws -> Playlist? {
        try fetchAll(SDPlaylist.self)
            .first { $0.sourceProvider == provider.rawValue && $0.sourcePlaylistId == sourcePlaylistId }?
            .toDomain()
    }

    func allPlaylists() async throws -> [Playlist] {
        try fetchAll(SDPlaylist.self).map { $0.toDomain() }
    }

    func deletePlaylist(id: String) async throws {
        for playlist in try fetchAll(SDPlaylist.self) where playlist.id == id { modelContext.delete(playlist) }
        let snapshotIds = Set(try fetchAll(SDSnapshot.self).filter { $0.playlistId == id }.map(\.id))
        for snapshot in try fetchAll(SDSnapshot.self) where snapshot.playlistId == id { modelContext.delete(snapshot) }
        for track in try fetchAll(SDSnapshotTrack.self) where snapshotIds.contains(track.snapshotId) { modelContext.delete(track) }
        try persist()
    }

    // MARK: - SnapshotRepository

    func insertSnapshot(_ snapshot: PlaylistSnapshot, tracks: [SnapshotTrack]) async throws {
        modelContext.insert(SDSnapshot(snapshot))
        for track in tracks { modelContext.insert(SDSnapshotTrack(track)) }
        try persist()
    }

    func snapshot(id: String) async throws -> PlaylistSnapshot? {
        try fetchAll(SDSnapshot.self).first { $0.id == id }?.toDomain()
    }

    func snapshots(forPlaylist playlistId: String) async throws -> [PlaylistSnapshot] {
        try fetchAll(SDSnapshot.self)
            .filter { $0.playlistId == playlistId }
            .sorted { $0.createdAt < $1.createdAt }
            .map { $0.toDomain() }
    }

    func latestSnapshot(forPlaylist playlistId: String) async throws -> PlaylistSnapshot? {
        try fetchAll(SDSnapshot.self)
            .filter { $0.playlistId == playlistId }
            .max { $0.createdAt < $1.createdAt }?
            .toDomain()
    }

    func snapshotTracks(snapshotId: String) async throws -> [SnapshotTrack] {
        try fetchAll(SDSnapshotTrack.self)
            .filter { $0.snapshotId == snapshotId }
            .sorted { $0.position < $1.position }
            .map { $0.toDomain() }
    }

    // MARK: - JobRepository

    func upsertImportJob(_ job: ImportJob) async throws {
        if let existing = try fetchAll(SDImportJob.self).first(where: { $0.id == job.id }) {
            existing.apply(job)
        } else {
            modelContext.insert(SDImportJob(job))
        }
        try persist()
    }

    func importJob(id: String) async throws -> ImportJob? {
        try fetchAll(SDImportJob.self).first { $0.id == id }?.toDomain()
    }

    func allImportJobs() async throws -> [ImportJob] {
        try fetchAll(SDImportJob.self).sorted { $0.startedAt > $1.startedAt }.map { $0.toDomain() }
    }

    func upsertRestoreJob(_ job: RestoreJob) async throws {
        if let existing = try fetchAll(SDRestoreJob.self).first(where: { $0.id == job.id }) {
            existing.apply(job)
        } else {
            modelContext.insert(SDRestoreJob(job))
        }
        try persist()
    }

    func restoreJob(id: String) async throws -> RestoreJob? {
        try fetchAll(SDRestoreJob.self).first { $0.id == id }?.toDomain()
    }

    func allRestoreJobs() async throws -> [RestoreJob] {
        try fetchAll(SDRestoreJob.self).sorted { $0.startedAt > $1.startedAt }.map { $0.toDomain() }
    }

    func upsertUnmatched(_ tracks: [UnmatchedTrack]) async throws {
        let existing = try fetchAll(SDUnmatched.self)
        for track in tracks {
            if let match = existing.first(where: { $0.id == track.id }) {
                match.apply(track)
            } else {
                modelContext.insert(SDUnmatched(track))
            }
        }
        try persist()
    }

    func updateUnmatched(_ track: UnmatchedTrack) async throws {
        if let existing = try fetchAll(SDUnmatched.self).first(where: { $0.id == track.id }) {
            existing.apply(track)
        } else {
            modelContext.insert(SDUnmatched(track))
        }
        try persist()
    }

    func unmatched(forRestoreJob jobId: String) async throws -> [UnmatchedTrack] {
        try fetchAll(SDUnmatched.self)
            .filter { $0.restoreJobId == jobId }
            .sorted { $0.createdAt < $1.createdAt }
            .map { $0.toDomain() }
    }

    // MARK: - ExportRepository

    func upsertExport(_ export: Export) async throws {
        if let existing = try fetchAll(SDExport.self).first(where: { $0.id == export.id }) {
            modelContext.delete(existing)
        }
        modelContext.insert(SDExport(export))
        try persist()
    }

    func allExports() async throws -> [Export] {
        try fetchAll(SDExport.self).sorted { $0.createdAt > $1.createdAt }.map { $0.toDomain() }
    }

    // MARK: - ConnectedAccountRepository

    func upsertAccount(_ account: ConnectedAccount) async throws {
        if let existing = try fetchAll(SDAccount.self).first(where: { $0.id == account.id }) {
            existing.apply(account)
        } else {
            modelContext.insert(SDAccount(account))
        }
        try persist()
    }

    func account(provider: Provider) async throws -> ConnectedAccount? {
        try fetchAll(SDAccount.self).first { $0.provider == provider.rawValue }?.toDomain()
    }

    func allAccounts() async throws -> [ConnectedAccount] {
        try fetchAll(SDAccount.self).map { $0.toDomain() }
    }

    func deleteAccount(id: String) async throws {
        for account in try fetchAll(SDAccount.self) where account.id == id { modelContext.delete(account) }
        try persist()
    }

    // MARK: - VaultStore

    func deleteAllData() async throws {
        for model in try fetchAll(SDSnapshotTrack.self) { modelContext.delete(model) }
        for model in try fetchAll(SDSnapshot.self) { modelContext.delete(model) }
        for model in try fetchAll(SDMapping.self) { modelContext.delete(model) }
        for model in try fetchAll(SDUnmatched.self) { modelContext.delete(model) }
        for model in try fetchAll(SDExport.self) { modelContext.delete(model) }
        for model in try fetchAll(SDImportJob.self) { modelContext.delete(model) }
        for model in try fetchAll(SDRestoreJob.self) { modelContext.delete(model) }
        for model in try fetchAll(SDPlaylist.self) { modelContext.delete(model) }
        for model in try fetchAll(SDTrack.self) { modelContext.delete(model) }
        for model in try fetchAll(SDAccount.self) { modelContext.delete(model) }
        try persist()
    }
}
