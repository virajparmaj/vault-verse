import Testing
import Foundation
@testable import VaultVerseCore

@Suite("Export")
struct ExportServiceTests {
    private func importedStore() async throws -> InMemoryVaultStore {
        let store = InMemoryVaultStore()
        let connector = try MockAppleMusicService()
        try await PlaylistImportService(connector: connector, store: store).run()
        return store
    }

    @Test("JSON backup round-trips and carries the full snapshot")
    func jsonRoundTrips() async throws {
        let store = try await importedStore()
        let replay = try #require(try await store.allPlaylists().first { $0.title == "Apple Replay 2021" })
        let data = try await ExportService(store: store).exportJSONData(playlistId: replay.id)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(PlaylistBackup.self, from: data)
        #expect(backup.playlist.title == "Apple Replay 2021")
        #expect(backup.snapshots.first?.tracks.count == 6)
        #expect(backup.format == "vaultverse.playlist-backup")
    }

    @Test("CSV has the expected header and one row per track")
    func csvHeaderAndRows() async throws {
        let store = try await importedStore()
        let replay = try #require(try await store.allPlaylists().first { $0.title == "Apple Replay 2021" })
        let snapshot = try #require(try await store.latestSnapshot(forPlaylist: replay.id))
        let data = try await ExportService(store: store).exportSnapshotCSVData(snapshotId: snapshot.id)
        let csv = String(decoding: data, as: UTF8.self)
        let lines = csv.split(separator: "\n")
        #expect(lines.first == "position,title,artist,album,duration_ms,isrc,apple_music_id")
        #expect(lines.count == 7)
    }

    @Test("CSV fields with commas/quotes are escaped")
    func csvEscaping() {
        #expect(ExportService.csvField("plain") == "plain")
        #expect(ExportService.csvField("a,b") == "\"a,b\"")
        #expect(ExportService.csvField("say \"hi\"") == "\"say \"\"hi\"\"\"")
    }
}
