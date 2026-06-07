import Testing
@testable import VaultVerseCore

@Suite("Analytics")
struct AnalyticsServiceTests {
    private func importedStore() async throws -> InMemoryVaultStore {
        let store = InMemoryVaultStore()
        let connector = try MockAppleMusicService()
        try await PlaylistImportService(connector: connector, store: store).run()
        return store
    }

    @Test("Dashboard summary reflects the imported archive")
    func dashboardSummary() async throws {
        let store = try await importedStore()
        let summary = try await AnalyticsService(store: store).dashboardSummary()
        #expect(summary.totalPlaylists == 5)
        #expect(summary.totalTracks == 21)
        #expect(summary.totalSnapshots == 5)
        #expect(summary.largestPlaylistTitle == "Summer 2024")
        #expect(summary.restoreReadinessPercent > 80)
    }

    @Test("Recurring songs surface tracks shared across yearly playlists")
    func recurringSongs() async throws {
        let store = try await importedStore()
        let recurring = try await AnalyticsService(store: store).songsInMultiplePlaylists()
        #expect(recurring.contains { $0.title == "Blinding Lights" && $0.playlistCount == 2 })
    }

    @Test("Top artists are ranked by appearance count")
    func topArtists() async throws {
        let store = try await importedStore()
        let artists = try await AnalyticsService(store: store).topArtists(limit: 3)
        #expect(artists.count <= 3)
        #expect(artists.first!.count >= artists.last!.count)
    }

    @Test("Per-playlist restore readiness is computed")
    func playlistReadiness() async throws {
        let store = try await importedStore()
        let summer = try #require(try await store.allPlaylists().first { $0.title == "Summer 2024" })
        let readiness = try await AnalyticsService(store: store).restoreReadiness(playlistId: summer.id)
        #expect(readiness.total == 7)
        #expect(readiness.ready < readiness.total) // Beach Memo (local-only) isn't ready
    }
}
