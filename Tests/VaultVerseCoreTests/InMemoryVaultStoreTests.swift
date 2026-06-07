import Testing
@testable import VaultVerseCore

@Suite("In-memory store")
struct InMemoryVaultStoreTests {
    @Test("Track + mapping round-trip, including ISRC lookup")
    func trackAndMapping() async throws {
        let store = InMemoryVaultStore()
        let track = Track(title: "X", normalizedTitle: "x", primaryArtist: "Y", artists: ["Y"], normalizedArtist: "y", isrc: "USABC1234567")
        try await store.upsertTrack(track)

        #expect(try await store.track(id: track.id)?.title == "X")
        #expect(try await store.trackByISRC("usabc1234567")?.id == track.id)

        let mapping = TrackPlatformMapping(trackId: track.id, provider: .appleMusic, providerTrackId: "123", matchMethod: .isrc, confidenceScore: 100)
        try await store.upsertMapping(mapping)
        #expect(try await store.mapping(trackId: track.id, provider: .appleMusic)?.providerTrackId == "123")
    }

    @Test("Manual override wins over a higher-confidence automatic mapping")
    func manualOverrideWins() async throws {
        let store = InMemoryVaultStore()
        let trackId = "t1"
        try await store.upsertMapping(TrackPlatformMapping(trackId: trackId, provider: .appleMusic, providerTrackId: "auto", matchMethod: .isrc, confidenceScore: 100))
        try await store.upsertMapping(TrackPlatformMapping(trackId: trackId, provider: .appleMusic, providerTrackId: "manual", matchMethod: .manual, confidenceScore: 100, isManualOverride: true))
        #expect(try await store.manualOverride(trackId: trackId, provider: .appleMusic)?.providerTrackId == "manual")
        #expect(try await store.mapping(trackId: trackId, provider: .appleMusic)?.providerTrackId == "manual")
    }

    @Test("Snapshot tracks are returned ordered by position")
    func snapshotOrdering() async throws {
        let store = InMemoryVaultStore()
        let snapshot = PlaylistSnapshot(playlistId: "p", sourceProvider: .appleMusic, trackCount: 3)
        let tracks = [
            SnapshotTrack(snapshotId: snapshot.id, trackId: "c", position: 2, title: "C", artistName: "A"),
            SnapshotTrack(snapshotId: snapshot.id, trackId: "a", position: 0, title: "A", artistName: "A"),
            SnapshotTrack(snapshotId: snapshot.id, trackId: "b", position: 1, title: "B", artistName: "A"),
        ]
        try await store.insertSnapshot(snapshot, tracks: tracks)
        let read = try await store.snapshotTracks(snapshotId: snapshot.id)
        #expect(read.map(\.trackId) == ["a", "b", "c"])
    }

    @Test("deleteAllData clears the vault")
    func deleteAll() async throws {
        let store = InMemoryVaultStore()
        let connector = try MockAppleMusicService()
        try await PlaylistImportService(connector: connector, store: store).run()
        try await store.deleteAllData()
        #expect(try await store.allPlaylists().isEmpty)
        #expect(try await store.allTracks().isEmpty)
    }
}
