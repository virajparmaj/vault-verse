import Testing
@testable import VaultVerseCore

@Suite("Mock Apple Music connector")
struct MockAppleMusicServiceTests {
    private func service() throws -> MockAppleMusicService { try MockAppleMusicService() }

    @Test("Authenticates with the seed storefront")
    func authenticates() async throws {
        let auth = try await service().authenticate()
        #expect(auth.provider == .appleMusic)
        #expect(auth.storefront == "us")
    }

    @Test("Serves the seeded library playlists")
    func listsPlaylists() async throws {
        let svc = try service()
        let auth = try await svc.authenticate()
        let playlists = try await svc.fetchUserPlaylists(auth: auth)
        #expect(playlists.count == 5)
        #expect(playlists.contains { $0.name == "Apple Replay 2021" })
        #expect(playlists.contains { $0.providerPlaylistId == "pl.apple.empty.mixtape" })
    }

    @Test("Preserves track order; empty playlist is empty")
    func tracksAndOrder() async throws {
        let svc = try service()
        let auth = try await svc.authenticate()
        let tracks = try await svc.fetchPlaylistTracks(auth: auth, providerPlaylistId: "pl.apple.replay.2021")
        #expect(tracks.count == 6)
        #expect(tracks.first?.title == "Blinding Lights")

        let empty = try await svc.fetchPlaylistTracks(auth: auth, providerPlaylistId: "pl.apple.empty.mixtape")
        #expect(empty.isEmpty)
    }

    @Test("Unknown playlist throws playlistNotFound")
    func unknownPlaylistThrows() async throws {
        let svc = try service()
        let auth = try await svc.authenticate()
        await #expect(throws: VaultVerseError.self) {
            _ = try await svc.fetchPlaylistTracks(auth: auth, providerPlaylistId: "pl.does.not.exist")
        }
    }

    @Test("Catalog search by ISRC finds the track")
    func searchByISRC() async throws {
        let svc = try service()
        let auth = try await svc.authenticate()
        let results = try await svc.searchTrack(auth: auth, query: TrackSearchQuery(isrc: "USUG11904206"))
        #expect(results.contains { $0.title == "Blinding Lights" })
    }

    @Test("Region-unavailable track surfaces as such; local-only is absent")
    func availabilityEdges() async throws {
        let svc = try service()
        let auth = try await svc.authenticate()

        let houdini = try await svc.searchTrack(auth: auth, query: TrackSearchQuery(isrc: "GBAHT2400001"))
        #expect(houdini.first?.availability == .regionUnavailable)

        let local = try await svc.searchTrack(auth: auth, query: TrackSearchQuery(title: "Beach Memo (Voice Note)", artist: "Local Recording"))
        #expect(local.isEmpty) // local-only items have no catalog identity
    }

    @Test("Create then add tracks: only available catalog tracks succeed")
    func createAndAdd() async throws {
        let svc = try service()
        let auth = try await svc.authenticate()
        let created = try await svc.createPlaylist(auth: auth, input: CreatePlaylistInput(name: "Restored Replay 2021"))

        let result = try await svc.addTracks(
            auth: auth,
            providerPlaylistId: created.providerPlaylistId,
            providerTrackIds: ["1440857781", "1739191003", ""] // available, region-unavailable, local-only
        )
        #expect(result.requested == 3)
        #expect(result.added == 1)
        #expect(result.failedProviderTrackIds.count == 2)

        let added = await svc.addedTrackIds(forCreatedPlaylist: created.providerPlaylistId)
        #expect(added == ["1440857781"])
    }
}
