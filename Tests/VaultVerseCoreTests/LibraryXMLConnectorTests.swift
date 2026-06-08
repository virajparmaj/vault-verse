import Foundation
import Testing
@testable import VaultVerseCore

@Suite("Library XML connector")
struct LibraryXMLConnectorTests {

    /// A minimal but realistic Music "Export Library…" file:
    /// - three tracks (insertion order 101, 102, 103),
    /// - a system "Library" playlist (Master) that must be skipped,
    /// - "Road Trip" whose Playlist Items intentionally reverse track order (102 → 101),
    /// - "Chill" with a single track.
    private static let validXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Major Version</key><integer>1</integer>
        <key>Tracks</key>
        <dict>
            <key>101</key>
            <dict>
                <key>Track ID</key><integer>101</integer>
                <key>Name</key><string>Blinding Lights</string>
                <key>Artist</key><string>The Weeknd</string>
                <key>Album</key><string>After Hours</string>
                <key>Total Time</key><integer>200040</integer>
                <key>Date Added</key><date>2021-01-15T08:30:00Z</date>
                <key>Location</key><string>file:///Users/test/Music/blinding.m4a</string>
            </dict>
            <key>102</key>
            <dict>
                <key>Track ID</key><integer>102</integer>
                <key>Name</key><string>Levitating</string>
                <key>Artist</key><string>Dua Lipa</string>
                <key>Album</key><string>Future Nostalgia</string>
                <key>Total Time</key><integer>203064</integer>
                <key>Date Added</key><date>2021-02-20T10:00:00Z</date>
            </dict>
            <key>103</key>
            <dict>
                <key>Track ID</key><integer>103</integer>
                <key>Name</key><string>Watermelon Sugar</string>
                <key>Artist</key><string>Harry Styles</string>
                <key>Album</key><string>Fine Line</string>
                <key>Total Time</key><integer>174000</integer>
            </dict>
        </dict>
        <key>Playlists</key>
        <array>
            <dict>
                <key>Name</key><string>Library</string>
                <key>Master</key><true/>
                <key>Playlist Persistent ID</key><string>0000MASTER</string>
                <key>Playlist Items</key>
                <array>
                    <dict><key>Track ID</key><integer>101</integer></dict>
                </array>
            </dict>
            <dict>
                <key>Name</key><string>Road Trip</string>
                <key>Playlist ID</key><integer>9001</integer>
                <key>Playlist Persistent ID</key><string>AAAA1111</string>
                <key>Playlist Items</key>
                <array>
                    <dict><key>Track ID</key><integer>102</integer></dict>
                    <dict><key>Track ID</key><integer>101</integer></dict>
                </array>
            </dict>
            <dict>
                <key>Name</key><string>Chill</string>
                <key>Playlist ID</key><integer>9002</integer>
                <key>Playlist Persistent ID</key><string>BBBB2222</string>
                <key>Playlist Items</key>
                <array>
                    <dict><key>Track ID</key><integer>103</integer></dict>
                </array>
            </dict>
        </array>
    </dict>
    </plist>
    """

    private func connector() throws -> LibraryXMLConnector {
        try LibraryXMLConnector(data: Data(Self.validXML.utf8))
    }

    @Test("Skips system playlists; serves the user's real ones")
    func listsUserPlaylists() async throws {
        let svc = try connector()
        let auth = try await svc.authenticate()
        let playlists = try await svc.fetchUserPlaylists(auth: auth)

        #expect(playlists.count == 2)                                   // "Library" (Master) is skipped
        #expect(playlists.contains { $0.name == "Road Trip" })
        #expect(playlists.contains { $0.name == "Chill" })
        #expect(!playlists.contains { $0.name == "Library" })
    }

    @Test("Preserves Playlist Items order, not Tracks-dict order")
    func preservesTrackOrder() async throws {
        let svc = try connector()
        let auth = try await svc.authenticate()
        let tracks = try await svc.fetchPlaylistTracks(auth: auth, providerPlaylistId: "AAAA1111")

        #expect(tracks.map(\.title) == ["Levitating", "Blinding Lights"])
    }

    @Test("Maps name, artist, album, duration, dateAdded, and file location")
    func mapsMetadata() async throws {
        let svc = try connector()
        let auth = try await svc.authenticate()
        let tracks = try await svc.fetchPlaylistTracks(auth: auth, providerPlaylistId: "AAAA1111")
        let blinding = try #require(tracks.first { $0.title == "Blinding Lights" })

        #expect(blinding.artistName == "The Weeknd")
        #expect(blinding.albumName == "After Hours")
        #expect(blinding.durationMs == 200040)
        #expect(blinding.addedAt != nil)
        #expect(blinding.providerURI == "file:///Users/test/Music/blinding.m4a")
        #expect(blinding.providerTrackId == "101")
    }

    @Test("Unknown playlist throws playlistNotFound")
    func unknownPlaylistThrows() async throws {
        let svc = try connector()
        let auth = try await svc.authenticate()
        await #expect(throws: VaultVerseError.self) {
            _ = try await svc.fetchPlaylistTracks(auth: auth, providerPlaylistId: "does.not.exist")
        }
    }

    @Test("Searches the parsed catalog by title + artist")
    func searchCatalog() async throws {
        let svc = try connector()
        let auth = try await svc.authenticate()

        let hits = try await svc.searchTrack(auth: auth, query: TrackSearchQuery(title: "Watermelon Sugar", artist: "Harry Styles"))
        #expect(hits.contains { $0.title == "Watermelon Sugar" })

        let none = try await svc.searchTrack(auth: auth, query: TrackSearchQuery(title: "Nonexistent Song", artist: "Nobody"))
        #expect(none.isEmpty)
    }

    @Test("Write-back is not supported (createPlaylist / addTracks throw)")
    func writeBackThrows() async throws {
        let svc = try connector()
        let auth = try await svc.authenticate()

        await #expect(throws: VaultVerseError.self) {
            _ = try await svc.createPlaylist(auth: auth, input: CreatePlaylistInput(name: "X"))
        }
        await #expect(throws: VaultVerseError.self) {
            _ = try await svc.addTracks(auth: auth, providerPlaylistId: "AAAA1111", providerTrackIds: ["101"])
        }
    }

    @Test("restoreToFile writes an ordered .m3u with local file paths + a JSON backup")
    func restoreProducesFiles() async throws {
        let store = InMemoryVaultStore()
        let svc = try connector()

        try await PlaylistImportService(connector: svc, store: store).run()
        let playlist = try #require((try await store.allPlaylists()).first { $0.title == "Road Trip" })
        let snapshot = try #require(try await store.latestSnapshot(forPlaylist: playlist.id))

        let restore = PlaylistRestoreService(connector: svc, store: store)
        let preflight = try await restore.preflight(snapshotId: snapshot.id, targetProvider: .appleMusic)

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vaultverse-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        let report = try await restore.restoreToFile(restoreJobId: preflight.restoreJobId, directory: dir)

        // No provider write-back happened (createdPlaylistId stays nil), files are produced.
        #expect(report.createdPlaylistId == nil)
        let m3uPath = try #require(report.m3uPath)
        #expect(report.jsonPath != nil)

        let m3u = try String(contentsOfFile: m3uPath, encoding: .utf8)
        let levitating = try #require(m3u.range(of: "Levitating"))
        let blinding = try #require(m3u.range(of: "Blinding Lights"))
        #expect(levitating.lowerBound < blinding.lowerBound)           // Playlist Items order preserved
        #expect(m3u.contains("/Users/test/Music/blinding.m4a"))         // file:// Location → real m3u entry
    }

    @Test("Rejects empty, garbage, and non-library input")
    func rejectsBadInput() throws {
        #expect(throws: VaultVerseError.self) {
            _ = try LibraryXMLConnector(data: Data())
        }
        #expect(throws: VaultVerseError.self) {
            _ = try LibraryXMLConnector(data: Data("this is definitely not a plist".utf8))
        }
        // A valid plist that isn't a library export (no Tracks/Playlists).
        let wrongShape = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict><key>Hello</key><string>World</string></dict></plist>
        """
        #expect(throws: VaultVerseError.self) {
            _ = try LibraryXMLConnector(data: Data(wrongShape.utf8))
        }
    }
}
