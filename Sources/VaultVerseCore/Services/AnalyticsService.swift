import Foundation

public struct DashboardSummary: Sendable, Hashable {
    public let totalPlaylists: Int
    public let totalTracks: Int
    public let totalSnapshots: Int
    public let connectedProviders: [Provider]
    public let lastBackupDate: Date?
    public let restoreReadinessPercent: Int
    public let mappedTracks: Int
    public let unresolvedUnmatchedCount: Int
    public let oldestPlaylistTitle: String?
    public let oldestPlaylistDate: Date?
    public let largestPlaylistTitle: String?
    public let largestPlaylistTrackCount: Int?
}

public struct NamedCount: Sendable, Hashable, Identifiable {
    public var id: String { name }
    public let name: String
    public let count: Int
}

public struct ArchiveGrowthPoint: Sendable, Hashable {
    public let date: Date
    public let cumulativeTracks: Int
}

public struct RecurringTrack: Sendable, Hashable, Identifiable {
    public var id: String { trackId }
    public let trackId: String
    public let title: String
    public let artist: String
    public let playlistCount: Int
}

public struct RestoreReadiness: Sendable, Hashable {
    public let percent: Int
    public let ready: Int
    public let total: Int
}

/// Computes dashboard metrics and "timeline of taste" insights from the vault.
/// Analytics reflect the *current* library — the latest snapshot of each playlist.
public struct AnalyticsService: Sendable {
    private let store: any VaultStore

    public init(store: any VaultStore) {
        self.store = store
    }

    // MARK: - Dashboard

    public func dashboardSummary() async throws -> DashboardSummary {
        let playlists = try await store.allPlaylists()
        let latest = try await latestSnapshotTracks()

        var distinctTrackIds = Set<String>()
        for entry in latest { for track in entry.tracks { distinctTrackIds.insert(track.trackId) } }

        var totalSnapshots = 0
        for playlist in playlists {
            totalSnapshots += try await store.snapshots(forPlaylist: playlist.id).count
        }

        let accounts = try await store.allAccounts()
        let connected = accounts.filter { $0.status == .connected }.map(\.provider)

        let lastBackup = latest.map(\.snapshot.createdAt).max()
            ?? playlists.compactMap(\.lastSyncedAt).max()

        // Restore readiness across the whole archive.
        var ready = 0
        var total = 0
        for entry in latest {
            for snapshotTrack in entry.tracks {
                total += 1
                if try await isRestoreReady(trackId: snapshotTrack.trackId, provider: entry.playlist.sourceProvider) {
                    ready += 1
                }
            }
        }
        let readinessPercent = total == 0 ? 0 : Int((Double(ready) / Double(total) * 100).rounded())

        // Unresolved unmatched across all restore jobs.
        var unresolved = 0
        for job in try await store.allRestoreJobs() {
            unresolved += try await store.unmatched(forRestoreJob: job.id).filter { $0.resolvedAt == nil }.count
        }

        let oldest = playlists.min { $0.importedAt < $1.importedAt }
        let largest = playlists.max { $0.trackCount < $1.trackCount }

        return DashboardSummary(
            totalPlaylists: playlists.count,
            totalTracks: distinctTrackIds.count,
            totalSnapshots: totalSnapshots,
            connectedProviders: connected,
            lastBackupDate: lastBackup,
            restoreReadinessPercent: readinessPercent,
            mappedTracks: ready,
            unresolvedUnmatchedCount: unresolved,
            oldestPlaylistTitle: oldest?.title,
            oldestPlaylistDate: oldest?.importedAt,
            largestPlaylistTitle: largest?.title,
            largestPlaylistTrackCount: largest?.trackCount
        )
    }

    public func restoreReadiness(playlistId: String) async throws -> RestoreReadiness {
        guard let playlist = try await store.playlist(id: playlistId),
              let snapshot = try await store.latestSnapshot(forPlaylist: playlistId) else {
            return RestoreReadiness(percent: 0, ready: 0, total: 0)
        }
        let tracks = try await store.snapshotTracks(snapshotId: snapshot.id)
        var ready = 0
        for snapshotTrack in tracks where try await isRestoreReady(trackId: snapshotTrack.trackId, provider: playlist.sourceProvider) {
            ready += 1
        }
        let percent = tracks.isEmpty ? 100 : Int((Double(ready) / Double(tracks.count) * 100).rounded())
        return RestoreReadiness(percent: percent, ready: ready, total: tracks.count)
    }

    // MARK: - Taste insights

    public func topArtists(limit: Int = 10) async throws -> [NamedCount] {
        try await topCounts(limit: limit) { $0.artistName }
    }

    public func topAlbums(limit: Int = 10) async throws -> [NamedCount] {
        try await topCounts(limit: limit) { $0.albumName }
    }

    public func archiveGrowth() async throws -> [ArchiveGrowthPoint] {
        let playlists = try await store.allPlaylists()
        var allSnapshots: [PlaylistSnapshot] = []
        for playlist in playlists {
            allSnapshots.append(contentsOf: try await store.snapshots(forPlaylist: playlist.id))
        }
        let ordered = allSnapshots.sorted { $0.createdAt < $1.createdAt }
        var seen = Set<String>()
        var points: [ArchiveGrowthPoint] = []
        for snapshot in ordered {
            for snapshotTrack in try await store.snapshotTracks(snapshotId: snapshot.id) {
                seen.insert(snapshotTrack.trackId)
            }
            points.append(ArchiveGrowthPoint(date: snapshot.createdAt, cumulativeTracks: seen.count))
        }
        return points
    }

    /// Songs that appear in two or more different playlists (latest snapshots) —
    /// e.g. a track in both "Apple Replay 2021" and "Apple Replay 2022".
    public func songsInMultiplePlaylists(minPlaylists: Int = 2) async throws -> [RecurringTrack] {
        let latest = try await latestSnapshotTracks()
        var playlistsByTrack: [String: Set<String>] = [:]
        var labelByTrack: [String: (title: String, artist: String)] = [:]
        for entry in latest {
            for snapshotTrack in entry.tracks {
                playlistsByTrack[snapshotTrack.trackId, default: []].insert(entry.playlist.id)
                labelByTrack[snapshotTrack.trackId] = (snapshotTrack.title, snapshotTrack.artistName)
            }
        }
        return playlistsByTrack
            .filter { $0.value.count >= minPlaylists }
            .compactMap { trackId, playlistIds -> RecurringTrack? in
                guard let label = labelByTrack[trackId] else { return nil }
                return RecurringTrack(trackId: trackId, title: label.title, artist: label.artist, playlistCount: playlistIds.count)
            }
            .sorted { $0.playlistCount > $1.playlistCount }
    }

    // MARK: - Helpers

    private struct LatestEntry {
        let playlist: Playlist
        let snapshot: PlaylistSnapshot
        let tracks: [SnapshotTrack]
    }

    private func latestSnapshotTracks() async throws -> [LatestEntry] {
        var entries: [LatestEntry] = []
        for playlist in try await store.allPlaylists() {
            guard let snapshot = try await store.latestSnapshot(forPlaylist: playlist.id) else { continue }
            let tracks = try await store.snapshotTracks(snapshotId: snapshot.id)
            entries.append(LatestEntry(playlist: playlist, snapshot: snapshot, tracks: tracks))
        }
        return entries
    }

    private func topCounts(limit: Int, key: (SnapshotTrack) -> String?) async throws -> [NamedCount] {
        let latest = try await latestSnapshotTracks()
        var counts: [String: Int] = [:]
        for entry in latest {
            for snapshotTrack in entry.tracks {
                guard let name = key(snapshotTrack), !name.isEmpty else { continue }
                counts[name, default: 0] += 1
            }
        }
        let named = counts.map { NamedCount(name: $0.key, count: $0.value) }
        let sorted = named.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.name < rhs.name
        }
        return Array(sorted.prefix(limit))
    }

    private func isRestoreReady(trackId: String, provider: Provider) async throws -> Bool {
        if let mapping = try await store.mapping(trackId: trackId, provider: provider),
           mapping.confidenceScore >= TrackMatchingService.confidentThreshold,
           mapping.availabilityStatus != .regionUnavailable,
           mapping.availabilityStatus != .notFound,
           !mapping.providerTrackId.isEmpty {
            return true
        }
        if let track = try await store.track(id: trackId), let isrc = track.isrc, !isrc.isEmpty {
            return true
        }
        return false
    }
}
