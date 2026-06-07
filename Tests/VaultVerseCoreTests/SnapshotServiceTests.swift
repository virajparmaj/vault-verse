import Testing
@testable import VaultVerseCore

@Suite("Snapshots")
struct SnapshotServiceTests {
    private func track(_ trackId: String, _ position: Int, title: String = "T", artist: String = "A", album: String? = nil, durationMs: Int? = nil) -> SnapshotTrack {
        SnapshotTrack(snapshotId: "s", trackId: trackId, position: position, title: title, artistName: artist, albumName: album, durationMs: durationMs)
    }

    private func snapshot(title: String?, artworkURL: String? = nil) -> PlaylistSnapshot {
        PlaylistSnapshot(playlistId: "p", sourceProvider: .appleMusic, playlistTitle: title, playlistArtworkURL: artworkURL, trackCount: 0)
    }

    @Test("Checksum is stable and order-sensitive")
    func checksum() {
        let ordered = [track("1", 0), track("2", 1)]
        let reordered = [track("2", 0), track("1", 1)]
        #expect(SnapshotService.checksum(for: ordered) == SnapshotService.checksum(for: ordered))
        #expect(SnapshotService.checksum(for: ordered) != SnapshotService.checksum(for: reordered))
    }

    @Test("Diff detects add / remove / reorder / title change")
    func diff() {
        let old = snapshot(title: "My List")
        let new = snapshot(title: "My List (v2)")
        let oldTracks = [track("1", 0, title: "One"), track("2", 1, title: "Two")]
        let newTracks = [track("2", 0, title: "Two"), track("3", 1, title: "Three")]
        let result = SnapshotService.diff(oldSnapshot: old, oldTracks: oldTracks, newSnapshot: new, newTracks: newTracks)
        #expect(result.added.map(\.trackId) == ["3"])
        #expect(result.removed.map(\.trackId) == ["1"])
        #expect(result.reordered.contains { $0.trackId == "2" })
        #expect(result.titleChanged)
        #expect(result.hasChanges)
    }

    @Test("Diff detects album metadata change")
    func metadataDiff() {
        let snap = snapshot(title: "X")
        let before = [track("1", 0, album: "Original")]
        let after = [track("1", 0, album: "Deluxe")]
        let result = SnapshotService.diff(oldSnapshot: snap, oldTracks: before, newSnapshot: snap, newTracks: after)
        #expect(result.metadataChanged.contains { $0.field == "album" })
    }

    @Test("Identical contents → no material change")
    func noChange() {
        let snap = snapshot(title: "X")
        let tracks = [track("1", 0), track("2", 1)]
        let result = SnapshotService.diff(oldSnapshot: snap, oldTracks: tracks, newSnapshot: snap, newTracks: tracks)
        #expect(!result.hasChanges)
        #expect(result.summary.isNoMaterialChange)
    }
}
