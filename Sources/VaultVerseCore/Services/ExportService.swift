import Foundation

// MARK: - Backup document shapes (the JSON export format)

public struct PlaylistBackup: Codable, Sendable {
    public let format: String
    public let formatVersion: Int
    public let exportedAt: Date
    public let playlist: Playlist
    public let snapshots: [SnapshotBackup]
}

public struct SnapshotBackup: Codable, Sendable {
    public let snapshot: PlaylistSnapshot
    public let tracks: [SnapshotTrackBackup]
}

public struct SnapshotTrackBackup: Codable, Sendable {
    public let position: Int
    public let track: Track
    public let snapshotTrack: SnapshotTrack
    public let mappings: [TrackPlatformMapping]
}

/// Generates open, portable backups. Users are never locked in: a JSON export is
/// a complete, self-describing copy of a playlist's history and mappings; a CSV
/// is the human-readable track list.
public struct ExportService: Sendable {
    private let store: any VaultStore

    public init(store: any VaultStore) {
        self.store = store
    }

    // MARK: JSON

    public func buildBackup(playlistId: String) async throws -> PlaylistBackup {
        guard let playlist = try await store.playlist(id: playlistId) else {
            throw VaultVerseError.playlistNotFound(playlistId)
        }
        let snapshots = try await store.snapshots(forPlaylist: playlistId)
        var snapshotBackups: [SnapshotBackup] = []
        for snapshot in snapshots {
            let snapshotTracks = try await store.snapshotTracks(snapshotId: snapshot.id)
            var trackBackups: [SnapshotTrackBackup] = []
            for snapshotTrack in snapshotTracks {
                guard let track = try await store.track(id: snapshotTrack.trackId) else { continue }
                let mappings = try await store.mappings(forTrack: track.id)
                trackBackups.append(SnapshotTrackBackup(
                    position: snapshotTrack.position,
                    track: track,
                    snapshotTrack: snapshotTrack,
                    mappings: mappings
                ))
            }
            snapshotBackups.append(SnapshotBackup(snapshot: snapshot, tracks: trackBackups))
        }
        return PlaylistBackup(
            format: "vaultverse.playlist-backup",
            formatVersion: 1,
            exportedAt: Date(),
            playlist: playlist,
            snapshots: snapshotBackups
        )
    }

    public func exportJSONData(playlistId: String) async throws -> Data {
        let backup = try await buildBackup(playlistId: playlistId)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(backup)
        } catch {
            throw VaultVerseError.exportFailed("JSON encode: \(error.localizedDescription)")
        }
    }

    // MARK: CSV

    public func exportSnapshotCSVData(snapshotId: String) async throws -> Data {
        guard let snapshot = try await store.snapshot(id: snapshotId) else {
            throw VaultVerseError.snapshotNotFound(snapshotId)
        }
        let snapshotTracks = try await store.snapshotTracks(snapshotId: snapshot.id)
        let headers = ["position", "title", "artist", "album", "duration_ms", "isrc", "apple_music_id"]
        var rows: [[String]] = []
        for snapshotTrack in snapshotTracks {
            let track = try await store.track(id: snapshotTrack.trackId)
            rows.append([
                String(snapshotTrack.position + 1),
                snapshotTrack.title,
                snapshotTrack.artistName,
                snapshotTrack.albumName ?? "",
                snapshotTrack.durationMs.map(String.init) ?? "",
                track?.isrc ?? "",
                snapshotTrack.sourceProviderTrackId ?? "",
            ])
        }
        let csv = Self.csv(headers: headers, rows: rows)
        guard let data = csv.data(using: .utf8) else {
            throw VaultVerseError.exportFailed("CSV encode")
        }
        return data
    }

    // MARK: Write + record

    @discardableResult
    public func writeAndRecord(
        data: Data,
        format: ExportFormat,
        playlistId: String?,
        snapshotId: String?,
        suggestedName: String,
        directory: URL? = nil
    ) async throws -> (export: Export, url: URL) {
        let dir = directory ?? Self.defaultExportsDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(Self.sanitize(suggestedName)).appendingPathExtension(format.rawValue)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw VaultVerseError.exportFailed("write \(url.lastPathComponent): \(error.localizedDescription)")
        }
        let export = Export(
            playlistId: playlistId,
            snapshotId: snapshotId,
            format: format,
            fileURL: url.path,
            byteCount: data.count
        )
        try await store.upsertExport(export)
        return (export, url)
    }

    public static func defaultExportsDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("VaultVerse/Exports", isDirectory: true)
    }

    // MARK: - CSV helpers (shared with the restore "missing tracks" report)

    public static func csv(headers: [String], rows: [[String]]) -> String {
        var lines = [headers.map(csvField).joined(separator: ",")]
        for row in rows {
            lines.append(row.map(csvField).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static func sanitize(_ name: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_ ")
        let cleaned = String(name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return cleaned.trimmingCharacters(in: .whitespaces).isEmpty ? "vaultverse-export" : cleaned
    }
}
