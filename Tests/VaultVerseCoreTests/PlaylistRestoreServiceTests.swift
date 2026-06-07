import Testing
import Foundation
@testable import VaultVerseCore

@Suite("Playlist restore")
struct PlaylistRestoreServiceTests {
    private struct Fixture {
        let store: InMemoryVaultStore
        let connector: MockAppleMusicService
        let snapshot: PlaylistSnapshot
    }

    private func summerFixture() async throws -> Fixture {
        let store = InMemoryVaultStore()
        let connector = try MockAppleMusicService()
        try await PlaylistImportService(connector: connector, store: store).run()
        let summer = try #require(try await store.allPlaylists().first { $0.title == "Summer 2024" })
        let snapshot = try #require(try await store.latestSnapshot(forPlaylist: summer.id))
        return Fixture(store: store, connector: connector, snapshot: snapshot)
    }

    @Test("Preflight buckets the Summer 2024 snapshot correctly")
    func preflightBuckets() async throws {
        let fixture = try await summerFixture()
        let preflight = try await PlaylistRestoreService(connector: fixture.connector, store: fixture.store)
            .preflight(snapshotId: fixture.snapshot.id, targetProvider: .appleMusic)
        #expect(preflight.confidentCount == 4)
        #expect(preflight.reviewCount == 1)
        #expect(preflight.unavailableCount == 1)
        #expect(preflight.unmatchedCount == 1)
    }

    @Test("A resolved manual match is remembered on the next preflight")
    func manualMatchMemory() async throws {
        let fixture = try await summerFixture()
        let restorer = PlaylistRestoreService(connector: fixture.connector, store: fixture.store)

        let preflight = try await restorer.preflight(snapshotId: fixture.snapshot.id, targetProvider: .appleMusic)
        let unmatched = try await fixture.store.unmatched(forRestoreJob: preflight.restoreJobId)
        let review = try #require(unmatched.first { $0.reason.localizedCaseInsensitiveContains("review") })
        let pick = try #require(review.suggestedMatches.first)
        try await restorer.resolveMatch(restoreJobId: preflight.restoreJobId, unmatchedTrackId: review.id, chosenProviderTrackId: pick.providerTrackId, providerURI: pick.providerURI)

        let second = try await restorer.preflight(snapshotId: fixture.snapshot.id, targetProvider: .appleMusic)
        #expect(second.confidentCount == 5)
        #expect(second.reviewCount == 0)
    }

    @Test("Confirm restores confident + resolved tracks and reports honestly")
    func confirmReport() async throws {
        let fixture = try await summerFixture()
        let restorer = PlaylistRestoreService(connector: fixture.connector, store: fixture.store)

        let preflight = try await restorer.preflight(snapshotId: fixture.snapshot.id, targetProvider: .appleMusic)
        let unmatched = try await fixture.store.unmatched(forRestoreJob: preflight.restoreJobId)
        if let review = unmatched.first(where: { $0.reason.localizedCaseInsensitiveContains("review") }),
           let pick = review.suggestedMatches.first {
            try await restorer.resolveMatch(restoreJobId: preflight.restoreJobId, unmatchedTrackId: review.id, chosenProviderTrackId: pick.providerTrackId)
        }

        let report = try await restorer.confirm(restoreJobId: preflight.restoreJobId)
        #expect(report.total == 7)
        #expect(report.restored == 5)
        #expect(report.skipped == 2)
        #expect(report.failed == 0)
        #expect(report.createdPlaylistId != nil)
        #expect(report.missingTracksCSVPath != nil)
    }

    @Test("Preflight does not create anything in the provider")
    func preflightHasNoSideEffects() async throws {
        let fixture = try await summerFixture()
        let restorer = PlaylistRestoreService(connector: fixture.connector, store: fixture.store)
        let preflight = try await restorer.preflight(snapshotId: fixture.snapshot.id, targetProvider: .appleMusic)
        let job = try #require(try await fixture.store.restoreJob(id: preflight.restoreJobId))
        #expect(job.createdTargetPlaylistId == nil)
        #expect(job.status == .pending)
    }
}
