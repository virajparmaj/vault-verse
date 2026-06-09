import Foundation
import SwiftData
import VaultVerseCore

/// SwiftData-backed implementation of the `VaultStore` contract.
///
/// `@ModelActor` gives this its own actor-isolated `ModelContext`, so it is safe
/// to share across concurrent service calls. Behavior matches `InMemoryVaultStore`,
/// the reference implementation exercised by the test suite.
///
/// **Performance:** point lookups use `FetchDescriptor` + `#Predicate` (and
/// `fetchLimit` for single-row reads) so SQLite filters server-side and we only
/// materialize matching rows. The earlier "fetch the whole table, filter in Swift"
/// approach was O(n) per lookup → O(n²) across an import or a dashboard pass, which
/// made a real (thousands-of-tracks) library appear to hang/load empty.
@ModelActor
actor SwiftDataVaultStore: VaultStore {

    // MARK: - Generic helpers

    /// Fetch matching rows with an optional sort and limit (server-side filtering).
    private func fetch<T: PersistentModel>(
        _ predicate: Predicate<T>,
        sortBy: [SortDescriptor<T>] = [],
        limit: Int? = nil
    ) throws -> [T] {
        var descriptor = FetchDescriptor<T>(predicate: predicate, sortBy: sortBy)
        if let limit { descriptor.fetchLimit = limit }
        return try modelContext.fetch(descriptor)
    }

    private func fetchAll<T: PersistentModel>(_ type: T.Type, sortBy: [SortDescriptor<T>] = []) throws -> [T] {
        try modelContext.fetch(FetchDescriptor<T>(sortBy: sortBy))
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
        let id = track.id
        if let existing = try fetch(#Predicate<SDTrack> { $0.id == id }, limit: 1).first {
            existing.apply(track)
        } else {
            modelContext.insert(SDTrack(track))
        }
        try persist()
    }

    func track(id: String) async throws -> Track? {
        try fetch(#Predicate<SDTrack> { $0.id == id }, limit: 1).first?.toDomain()
    }

    func trackByISRC(_ isrc: String) async throws -> Track? {
        guard !isrc.isEmpty else { return nil }
        // ISRCs are canonical; match case-insensitively to mirror InMemoryVaultStore.
        let candidates = try fetch(#Predicate<SDTrack> { $0.isrc != nil })
        return candidates.first { $0.isrc?.caseInsensitiveCompare(isrc) == .orderedSame }?.toDomain()
    }

    func findTrack(normalizedTitle: String, normalizedArtist: String, durationMs: Int?, toleranceMs: Int) async throws -> Track? {
        // Narrow on the indexed-ish title+artist match server-side, then apply the
        // duration tolerance (a range, not expressible in a simple predicate) in Swift
        // over the (tiny) candidate set.
        let candidates = try fetch(#Predicate<SDTrack> {
            $0.normalizedTitle == normalizedTitle && $0.normalizedArtist == normalizedArtist
        })
        return candidates.first { Self.close($0.durationMs, durationMs, toleranceMs) }?.toDomain()
    }

    func allTracks() async throws -> [Track] {
        try fetchAll(SDTrack.self).map { $0.toDomain() }
    }

    // MARK: - MappingRepository

    func upsertMapping(_ mapping: TrackPlatformMapping) async throws {
        let id = mapping.id
        if let existing = try fetch(#Predicate<SDMapping> { $0.id == id }, limit: 1).first {
            modelContext.delete(existing)
        }
        modelContext.insert(SDMapping(mapping))
        try persist()
    }

    func mappings(forTrack trackId: String) async throws -> [TrackPlatformMapping] {
        try fetch(#Predicate<SDMapping> { $0.trackId == trackId }).map { $0.toDomain() }
    }

    func mapping(trackId: String, provider: Provider) async throws -> TrackPlatformMapping? {
        let providerRaw = provider.rawValue
        let candidates = try fetch(#Predicate<SDMapping> { $0.trackId == trackId && $0.provider == providerRaw })
        return candidates.sorted {
            if $0.isManualOverride != $1.isManualOverride { return $0.isManualOverride }
            return $0.confidenceScore > $1.confidenceScore
        }.first?.toDomain()
    }

    func manualOverride(trackId: String, provider: Provider) async throws -> TrackPlatformMapping? {
        let providerRaw = provider.rawValue
        return try fetch(#Predicate<SDMapping> {
            $0.trackId == trackId && $0.provider == providerRaw && $0.isManualOverride
        }, limit: 1).first?.toDomain()
    }

    func allMappings() async throws -> [TrackPlatformMapping] {
        try fetchAll(SDMapping.self).map { $0.toDomain() }
    }

    // MARK: - PlaylistRepository

    func upsertPlaylist(_ playlist: Playlist) async throws {
        let id = playlist.id
        if let existing = try fetch(#Predicate<SDPlaylist> { $0.id == id }, limit: 1).first {
            existing.apply(playlist)
        } else {
            modelContext.insert(SDPlaylist(playlist))
        }
        try persist()
    }

    func playlist(id: String) async throws -> Playlist? {
        try fetch(#Predicate<SDPlaylist> { $0.id == id }, limit: 1).first?.toDomain()
    }

    func playlist(provider: Provider, sourcePlaylistId: String) async throws -> Playlist? {
        let providerRaw = provider.rawValue
        return try fetch(#Predicate<SDPlaylist> {
            $0.sourceProvider == providerRaw && $0.sourcePlaylistId == sourcePlaylistId
        }, limit: 1).first?.toDomain()
    }

    func allPlaylists() async throws -> [Playlist] {
        try fetchAll(SDPlaylist.self).map { $0.toDomain() }
    }

    func deletePlaylist(id: String) async throws {
        for playlist in try fetch(#Predicate<SDPlaylist> { $0.id == id }) { modelContext.delete(playlist) }
        let snapshots = try fetch(#Predicate<SDSnapshot> { $0.playlistId == id })
        let snapshotIds = snapshots.map(\.id)
        for snapshot in snapshots { modelContext.delete(snapshot) }
        for track in try fetch(#Predicate<SDSnapshotTrack> { snapshotIds.contains($0.snapshotId) }) {
            modelContext.delete(track)
        }
        try persist()
    }

    // MARK: - SnapshotRepository

    func insertSnapshot(_ snapshot: PlaylistSnapshot, tracks: [SnapshotTrack]) async throws {
        modelContext.insert(SDSnapshot(snapshot))
        for track in tracks { modelContext.insert(SDSnapshotTrack(track)) }
        try persist()
    }

    func snapshot(id: String) async throws -> PlaylistSnapshot? {
        try fetch(#Predicate<SDSnapshot> { $0.id == id }, limit: 1).first?.toDomain()
    }

    func snapshots(forPlaylist playlistId: String) async throws -> [PlaylistSnapshot] {
        try fetch(
            #Predicate<SDSnapshot> { $0.playlistId == playlistId },
            sortBy: [SortDescriptor(\.createdAt)]
        ).map { $0.toDomain() }
    }

    func latestSnapshot(forPlaylist playlistId: String) async throws -> PlaylistSnapshot? {
        try fetch(
            #Predicate<SDSnapshot> { $0.playlistId == playlistId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)],
            limit: 1
        ).first?.toDomain()
    }

    func snapshotTracks(snapshotId: String) async throws -> [SnapshotTrack] {
        try fetch(
            #Predicate<SDSnapshotTrack> { $0.snapshotId == snapshotId },
            sortBy: [SortDescriptor(\.position)]
        ).map { $0.toDomain() }
    }

    // MARK: - JobRepository

    func upsertImportJob(_ job: ImportJob) async throws {
        let id = job.id
        if let existing = try fetch(#Predicate<SDImportJob> { $0.id == id }, limit: 1).first {
            existing.apply(job)
        } else {
            modelContext.insert(SDImportJob(job))
        }
        try persist()
    }

    func importJob(id: String) async throws -> ImportJob? {
        try fetch(#Predicate<SDImportJob> { $0.id == id }, limit: 1).first?.toDomain()
    }

    func allImportJobs() async throws -> [ImportJob] {
        try fetchAll(SDImportJob.self, sortBy: [SortDescriptor(\.startedAt, order: .reverse)]).map { $0.toDomain() }
    }

    func upsertRestoreJob(_ job: RestoreJob) async throws {
        let id = job.id
        if let existing = try fetch(#Predicate<SDRestoreJob> { $0.id == id }, limit: 1).first {
            existing.apply(job)
        } else {
            modelContext.insert(SDRestoreJob(job))
        }
        try persist()
    }

    func restoreJob(id: String) async throws -> RestoreJob? {
        try fetch(#Predicate<SDRestoreJob> { $0.id == id }, limit: 1).first?.toDomain()
    }

    func allRestoreJobs() async throws -> [RestoreJob] {
        try fetchAll(SDRestoreJob.self, sortBy: [SortDescriptor(\.startedAt, order: .reverse)]).map { $0.toDomain() }
    }

    func upsertUnmatched(_ tracks: [UnmatchedTrack]) async throws {
        for track in tracks {
            let id = track.id
            if let match = try fetch(#Predicate<SDUnmatched> { $0.id == id }, limit: 1).first {
                match.apply(track)
            } else {
                modelContext.insert(SDUnmatched(track))
            }
        }
        try persist()
    }

    func updateUnmatched(_ track: UnmatchedTrack) async throws {
        let id = track.id
        if let existing = try fetch(#Predicate<SDUnmatched> { $0.id == id }, limit: 1).first {
            existing.apply(track)
        } else {
            modelContext.insert(SDUnmatched(track))
        }
        try persist()
    }

    func unmatched(forRestoreJob jobId: String) async throws -> [UnmatchedTrack] {
        try fetch(
            #Predicate<SDUnmatched> { $0.restoreJobId == jobId },
            sortBy: [SortDescriptor(\.createdAt)]
        ).map { $0.toDomain() }
    }

    // MARK: - ExportRepository

    func upsertExport(_ export: Export) async throws {
        let id = export.id
        if let existing = try fetch(#Predicate<SDExport> { $0.id == id }, limit: 1).first {
            modelContext.delete(existing)
        }
        modelContext.insert(SDExport(export))
        try persist()
    }

    func allExports() async throws -> [Export] {
        try fetchAll(SDExport.self, sortBy: [SortDescriptor(\.createdAt, order: .reverse)]).map { $0.toDomain() }
    }

    // MARK: - ConnectedAccountRepository

    func upsertAccount(_ account: ConnectedAccount) async throws {
        let id = account.id
        if let existing = try fetch(#Predicate<SDAccount> { $0.id == id }, limit: 1).first {
            existing.apply(account)
        } else {
            modelContext.insert(SDAccount(account))
        }
        try persist()
    }

    func account(provider: Provider) async throws -> ConnectedAccount? {
        let providerRaw = provider.rawValue
        return try fetch(#Predicate<SDAccount> { $0.provider == providerRaw }, limit: 1).first?.toDomain()
    }

    func allAccounts() async throws -> [ConnectedAccount] {
        try fetchAll(SDAccount.self).map { $0.toDomain() }
    }

    func deleteAccount(id: String) async throws {
        for account in try fetch(#Predicate<SDAccount> { $0.id == id }) { modelContext.delete(account) }
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
