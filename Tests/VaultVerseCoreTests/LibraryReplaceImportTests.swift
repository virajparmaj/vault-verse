import Foundation
import Testing
@testable import VaultVerseCore

/// Contract behind the app's "Replace current library?" import flow: importing a
/// real `Library.xml` after `deleteAllData()` must leave *only* the real library —
/// no demo/seed residue — while a plain re-import (no wipe) keeps both. The app
/// wires the wipe (`AppEnvironment.deleteAllData()` → `store.deleteAllData()`) ahead
/// of the import; this exercises the store + import service that flow depends on.
@Suite("Replace-on-import contract")
struct LibraryReplaceImportTests {

    /// A minimal real-library export with exactly two user playlists (the system
    /// "Library"/Master entry is skipped by the parser).
    private static let realLibraryXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Tracks</key>
        <dict>
            <key>101</key>
            <dict>
                <key>Track ID</key><integer>101</integer>
                <key>Name</key><string>Blinding Lights</string>
                <key>Artist</key><string>The Weeknd</string>
                <key>Total Time</key><integer>200040</integer>
            </dict>
            <key>102</key>
            <dict>
                <key>Track ID</key><integer>102</integer>
                <key>Name</key><string>Levitating</string>
                <key>Artist</key><string>Dua Lipa</string>
                <key>Total Time</key><integer>203064</integer>
            </dict>
        </dict>
        <key>Playlists</key>
        <array>
            <dict>
                <key>Name</key><string>Library</string>
                <key>Master</key><true/>
                <key>Playlist Persistent ID</key><string>0000MASTER</string>
                <key>Playlist Items</key>
                <array><dict><key>Track ID</key><integer>101</integer></dict></array>
            </dict>
            <dict>
                <key>Name</key><string>Road Trip</string>
                <key>Playlist Persistent ID</key><string>AAAA1111</string>
                <key>Playlist Items</key>
                <array>
                    <dict><key>Track ID</key><integer>102</integer></dict>
                    <dict><key>Track ID</key><integer>101</integer></dict>
                </array>
            </dict>
            <dict>
                <key>Name</key><string>Chill</string>
                <key>Playlist Persistent ID</key><string>BBBB2222</string>
                <key>Playlist Items</key>
                <array><dict><key>Track ID</key><integer>101</integer></dict></array>
            </dict>
        </array>
    </dict>
    </plist>
    """

    private func realLibrary() throws -> LibraryXMLConnector {
        try LibraryXMLConnector(data: Data(Self.realLibraryXML.utf8))
    }

    @Test("Wiping before a real import leaves no demo residue")
    func replaceWipesDemo() async throws {
        let store = InMemoryVaultStore()

        // Seed with the demo library — what "Load demo library" does.
        try await PlaylistImportService(connector: try MockAppleMusicService(), store: store).run()
        #expect(!(try await store.allPlaylists()).isEmpty)

        // Replace path: wipe, then import the real library.
        try await store.deleteAllData()
        try await PlaylistImportService(connector: try realLibrary(), store: store).run()

        // Only the real library's playlists remain.
        let titles = Set(try await store.allPlaylists().map(\.title))
        #expect(titles == ["Road Trip", "Chill"])
    }

    @Test("Merging without a wipe keeps both libraries")
    func mergeKeepsBoth() async throws {
        let store = InMemoryVaultStore()

        try await PlaylistImportService(connector: try MockAppleMusicService(), store: store).run()
        let demoCount = try await store.allPlaylists().count

        // Merge path: import the real library on top, no wipe.
        try await PlaylistImportService(connector: try realLibrary(), store: store).run()

        let playlists = try await store.allPlaylists()
        let titles = Set(playlists.map(\.title))
        #expect(titles.contains("Road Trip"))
        #expect(titles.contains("Chill"))
        #expect(playlists.count == demoCount + 2)   // both real playlists added alongside demo
    }

    @Test("deleteAllData clears every record type the vault holds")
    func deleteAllDataIsThorough() async throws {
        let store = InMemoryVaultStore()
        try await PlaylistImportService(connector: try realLibrary(), store: store).run()

        // Sanity: the import produced playlists, tracks, snapshots, a job, and an account.
        #expect(!(try await store.allPlaylists()).isEmpty)
        #expect(!(try await store.allTracks()).isEmpty)
        #expect(!(try await store.allImportJobs()).isEmpty)
        #expect(try await store.account(provider: .appleMusic) != nil)

        try await store.deleteAllData()

        #expect((try await store.allPlaylists()).isEmpty)
        #expect((try await store.allTracks()).isEmpty)
        #expect((try await store.allMappings()).isEmpty)
        #expect((try await store.allImportJobs()).isEmpty)
        #expect(try await store.account(provider: .appleMusic) == nil)
    }
}
