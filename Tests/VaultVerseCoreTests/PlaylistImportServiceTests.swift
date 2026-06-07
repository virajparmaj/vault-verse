import Testing
@testable import VaultVerseCore

@Suite("Playlist import")
struct PlaylistImportServiceTests {
    private func freshImport() async throws -> InMemoryVaultStore {
        let store = InMemoryVaultStore()
        let connector = try MockAppleMusicService()
        try await PlaylistImportService(connector: connector, store: store).run()
        return store
    }

    @Test("Imports every playlist and preserves track order")
    func importsAndPreservesOrder() async throws {
        let store = InMemoryVaultStore()
        let connector = try MockAppleMusicService()
        let job = try await PlaylistImportService(connector: connector, store: store).run()
        #expect(job.status == .succeeded)
        #expect(job.playlistsImported == 5)

        let playlists = try await store.allPlaylists()
        let replay = try #require(playlists.first { $0.title == "Apple Replay 2021" })
        let snapshot = try #require(try await store.latestSnapshot(forPlaylist: replay.id))
        let tracks = try await store.snapshotTracks(snapshotId: snapshot.id)
        #expect(tracks.map(\.position) == Array(0..<tracks.count))
        #expect(tracks.first?.title == "Blinding Lights")
    }

    @Test("Deduplicates the same song across playlists by ISRC")
    func dedupByISRC() async throws {
        let store = try await freshImport()
        let blinding = try await store.allTracks().filter { $0.isrc == "USUG11904206" }
        #expect(blinding.count == 1)
    }

    @Test("Re-import with no change creates no new snapshot")
    func noChangeNoSnapshot() async throws {
        let store = InMemoryVaultStore()
        let connector = try MockAppleMusicService()
        let service = PlaylistImportService(connector: connector, store: store)
        try await service.run()
        let replay = try #require(try await store.allPlaylists().first { $0.title == "Apple Replay 2021" })
        let before = try await store.snapshots(forPlaylist: replay.id).count
        try await service.run()
        let after = try await store.snapshots(forPlaylist: replay.id).count
        #expect(before == 1)
        #expect(after == before)
    }

    @Test("Local-only track is archived but has no provider mapping")
    func localOnlyArchivedWithoutMapping() async throws {
        let store = try await freshImport()
        let beach = try #require(try await store.allTracks().first { $0.title.contains("Beach Memo") })
        let mappings = try await store.mappings(forTrack: beach.id)
        #expect(mappings.isEmpty)
    }

    @Test("Source mapping is created for catalog tracks")
    func sourceMappingCreated() async throws {
        let store = try await freshImport()
        let blinding = try #require(try await store.trackByISRC("USUG11904206"))
        let mapping = try #require(try await store.mapping(trackId: blinding.id, provider: .appleMusic))
        #expect(mapping.providerTrackId == "1440857781")
        #expect(mapping.confidenceScore == 100)
    }

    @Test("Empty playlist still gets a (zero-track) snapshot")
    func emptyPlaylistSnapshot() async throws {
        let store = try await freshImport()
        let empty = try #require(try await store.allPlaylists().first { $0.title == "Empty Mixtape" })
        let snapshot = try #require(try await store.latestSnapshot(forPlaylist: empty.id))
        #expect(snapshot.trackCount == 0)
    }
}
