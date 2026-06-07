import Foundation

/// Pure snapshot math: stable checksums and version-to-version diffs.
public enum SnapshotService {

    // MARK: - Checksum

    /// A stable hash over ordered tracks + key metadata. Identical contents in
    /// the same order produce the same checksum; any add/remove/reorder/metadata
    /// change produces a different one.
    public static func checksum(for tracks: [SnapshotTrack]) -> String {
        let ordered = tracks.sorted { $0.position < $1.position }
        let lines = ordered.map { track in
            [
                String(track.position),
                track.trackId,
                TrackNormalizer.normalizeTitle(track.title),
                TrackNormalizer.normalizeArtist(track.artistName),
                track.durationMs.map(String.init) ?? "-"
            ].joined(separator: "|")
        }
        return Checksum.sha256Hex(lines.joined(separator: "\n"))
    }

    // MARK: - Diff

    public static func diff(
        oldSnapshot: PlaylistSnapshot,
        oldTracks: [SnapshotTrack],
        newSnapshot: PlaylistSnapshot,
        newTracks: [SnapshotTrack]
    ) -> SnapshotDiff {
        let oldOrdered = oldTracks.sorted { $0.position < $1.position }
        let newOrdered = newTracks.sorted { $0.position < $1.position }

        // First-occurrence position per trackId (duplicates collapse to first).
        var oldFirst: [String: SnapshotTrack] = [:]
        for track in oldOrdered where oldFirst[track.trackId] == nil { oldFirst[track.trackId] = track }
        var newFirst: [String: SnapshotTrack] = [:]
        for track in newOrdered where newFirst[track.trackId] == nil { newFirst[track.trackId] = track }

        let oldIds = Set(oldFirst.keys)
        let newIds = Set(newFirst.keys)

        let added = newOrdered
            .filter { !oldIds.contains($0.trackId) }
            .reduce(into: [DiffTrack]()) { acc, st in
                if !acc.contains(where: { $0.trackId == st.trackId }) {
                    acc.append(DiffTrack(trackId: st.trackId, title: st.title, artist: st.artistName))
                }
            }

        let removed = oldOrdered
            .filter { !newIds.contains($0.trackId) }
            .reduce(into: [DiffTrack]()) { acc, st in
                if !acc.contains(where: { $0.trackId == st.trackId }) {
                    acc.append(DiffTrack(trackId: st.trackId, title: st.title, artist: st.artistName))
                }
            }

        var reordered: [DiffReorder] = []
        var metadataChanged: [DiffMetadataChange] = []
        for id in oldIds.intersection(newIds) {
            guard let before = oldFirst[id], let after = newFirst[id] else { continue }
            if before.position != after.position {
                reordered.append(DiffReorder(
                    trackId: id, title: after.title, artist: after.artistName,
                    oldPosition: before.position, newPosition: after.position
                ))
            }
            if before.albumName != after.albumName {
                metadataChanged.append(DiffMetadataChange(
                    trackId: id, title: after.title, field: "album",
                    oldValue: before.albumName ?? "—", newValue: after.albumName ?? "—"
                ))
            }
            if before.durationMs != after.durationMs {
                metadataChanged.append(DiffMetadataChange(
                    trackId: id, title: after.title, field: "duration",
                    oldValue: formatDuration(before.durationMs), newValue: formatDuration(after.durationMs)
                ))
            }
        }

        let titleChanged = oldSnapshot.playlistTitle != newSnapshot.playlistTitle
        let coverChanged = oldSnapshot.playlistArtworkURL != newSnapshot.playlistArtworkURL

        return SnapshotDiff(
            added: added,
            removed: removed,
            reordered: reordered.sorted { $0.newPosition < $1.newPosition },
            metadataChanged: metadataChanged,
            titleChanged: titleChanged,
            oldTitle: oldSnapshot.playlistTitle,
            newTitle: newSnapshot.playlistTitle,
            coverChanged: coverChanged
        )
    }

    /// Summary of `newTracks` relative to `previousTracks` (nil = first snapshot).
    public static func changeSummary(previousTracks: [SnapshotTrack]?, newTracks: [SnapshotTrack]) -> SnapshotChangeSummary {
        guard let previousTracks else {
            return SnapshotChangeSummary(added: newTracks.count, note: "First snapshot")
        }
        let dummyOld = PlaylistSnapshot(playlistId: "", sourceProvider: .appleMusic, trackCount: previousTracks.count)
        let dummyNew = PlaylistSnapshot(playlistId: "", sourceProvider: .appleMusic, trackCount: newTracks.count)
        let d = diff(oldSnapshot: dummyOld, oldTracks: previousTracks, newSnapshot: dummyNew, newTracks: newTracks)
        return d.summary
    }

    private static func formatDuration(_ ms: Int?) -> String {
        guard let ms else { return "—" }
        let totalSeconds = ms / 1000
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

// MARK: - Diff value types

public struct DiffTrack: Sendable, Hashable, Identifiable {
    public var id: String { trackId }
    public let trackId: String
    public let title: String
    public let artist: String
}

public struct DiffReorder: Sendable, Hashable, Identifiable {
    public var id: String { trackId }
    public let trackId: String
    public let title: String
    public let artist: String
    public let oldPosition: Int
    public let newPosition: Int
}

public struct DiffMetadataChange: Sendable, Hashable, Identifiable {
    public var id: String { trackId + ":" + field }
    public let trackId: String
    public let title: String
    public let field: String
    public let oldValue: String
    public let newValue: String
}

public struct SnapshotDiff: Sendable, Hashable {
    public let added: [DiffTrack]
    public let removed: [DiffTrack]
    public let reordered: [DiffReorder]
    public let metadataChanged: [DiffMetadataChange]
    public let titleChanged: Bool
    public let oldTitle: String?
    public let newTitle: String?
    public let coverChanged: Bool

    public var hasChanges: Bool {
        !added.isEmpty || !removed.isEmpty || !reordered.isEmpty
            || !metadataChanged.isEmpty || titleChanged || coverChanged
    }

    public var summary: SnapshotChangeSummary {
        SnapshotChangeSummary(
            added: added.count,
            removed: removed.count,
            reordered: reordered.count,
            metadataChanged: metadataChanged.count,
            titleChanged: titleChanged,
            coverChanged: coverChanged,
            note: hasChanges ? nil : "No material change"
        )
    }

    /// e.g. "12 added · 4 removed · 31 reordered".
    public var humanSummary: String {
        if !hasChanges { return "No material change" }
        var parts: [String] = []
        if !added.isEmpty { parts.append("\(added.count) added") }
        if !removed.isEmpty { parts.append("\(removed.count) removed") }
        if !reordered.isEmpty { parts.append("\(reordered.count) reordered") }
        if !metadataChanged.isEmpty { parts.append("\(metadataChanged.count) changed") }
        if titleChanged { parts.append("title changed") }
        if coverChanged { parts.append("cover changed") }
        return parts.joined(separator: " · ")
    }
}
