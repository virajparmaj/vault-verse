import Testing
import Foundation
@testable import VaultVerseCore

/// End-to-end exercise of the whole product loop on the mock connector:
/// connect → import → snapshot → export → restore (with a manual resolution).
@Suite("Core loop (integration)")
struct CoreLoopIntegrationTests {
    @Test("Full connect → import → export → restore flow")
    func fullLoop() async throws {
        let store = InMemoryVaultStore()
        let connector = try MockAppleMusicService()

        // Import
        let importJob = try await PlaylistImportService(connector: connector, store: store).run()
        #expect(importJob.status == .succeeded)
        #expect(importJob.playlistsImported == 5)

        // A playlist with several snapshots-worth of edge cases
        let summer = try #require(try await store.allPlaylists().first { $0.title == "Summer 2024" })
        let snapshot = try #require(try await store.latestSnapshot(forPlaylist: summer.id))

        // Export both formats to a temp dir
        let exporter = ExportService(store: store)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vaultverse-tests-\(UUID().uuidString)")
        let json = try await exporter.exportJSONData(playlistId: summer.id)
        let (_, jsonURL) = try await exporter.writeAndRecord(data: json, format: .json, playlistId: summer.id, snapshotId: nil, suggestedName: "summer", directory: dir)
        #expect(FileManager.default.fileExists(atPath: jsonURL.path))

        // Restore: preflight → resolve review → confirm
        let restorer = PlaylistRestoreService(connector: connector, store: store)
        let preflight = try await restorer.preflight(snapshotId: snapshot.id, targetProvider: .appleMusic)
        #expect(preflight.total == 7)

        let unmatched = try await store.unmatched(forRestoreJob: preflight.restoreJobId)
        if let review = unmatched.first(where: { $0.reason.localizedCaseInsensitiveContains("review") }),
           let pick = review.suggestedMatches.first {
            try await restorer.resolveMatch(restoreJobId: preflight.restoreJobId, unmatchedTrackId: review.id, chosenProviderTrackId: pick.providerTrackId)
        }

        let report = try await restorer.confirm(restoreJobId: preflight.restoreJobId)
        #expect(report.restored == 5)
        #expect(report.failed == 0)

        // The created playlist actually received the restored tracks in the mock library.
        let createdId = try #require(report.createdPlaylistId)
        let added = await connector.addedTrackIds(forCreatedPlaylist: createdId)
        #expect(added.count == report.restored)

        try? FileManager.default.removeItem(at: dir)
    }
}
