import Foundation

/// Parsed, provider-neutral view of a Music / iTunes "Export Library…" file.
///
/// The classic `Library.xml` is an Apple property-list. This is the in-memory
/// result of decoding one: a user profile, ordered playlists, and the full track
/// catalog — all expressed as the same DTOs every connector returns.
public struct ParsedLibrary: Sendable {
    public struct Entry: Sendable {
        public let playlist: ProviderPlaylist
        public let tracks: [ProviderTrack]
        public init(playlist: ProviderPlaylist, tracks: [ProviderTrack]) {
            self.playlist = playlist
            self.tracks = tracks
        }
    }

    public let profile: ProviderUserProfile
    public let playlists: [Entry]
    public let catalog: [ProviderTrack]

    public init(profile: ProviderUserProfile, playlists: [Entry], catalog: [ProviderTrack]) {
        self.profile = profile
        self.playlists = playlists
        self.catalog = catalog
    }

    /// A valid, empty library — used as the launch placeholder before a file is picked.
    public static let empty = ParsedLibrary(
        profile: ProviderUserProfile(providerUserId: "library-xml", displayName: "Apple Music export", storefront: nil),
        playlists: [],
        catalog: []
    )
}

/// Decodes an exported `Library.xml` into a `ParsedLibrary`.
///
/// Everything here treats the file as untrusted input: it is size-capped, the
/// shape is validated before use, and any failure surfaces as a `VaultVerseError`
/// with a message the UI can show directly.
public enum LibraryXMLParser {
    /// Refuse absurdly large files outright (a huge library export is a few tens of MB).
    static let maxBytes = 200 * 1024 * 1024

    public static func parse(_ data: Data) throws -> ParsedLibrary {
        guard !data.isEmpty else {
            throw VaultVerseError.invalidInput("The selected file is empty. Pick a Music \"Export Library…\" .xml file.")
        }
        guard data.count <= maxBytes else {
            throw VaultVerseError.invalidInput("That file is too large to be a library export (over \(maxBytes / (1024 * 1024)) MB).")
        }

        let root: Any
        do {
            root = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        } catch {
            throw VaultVerseError.decodingFailed("Couldn't read the file as a property list: \(error.localizedDescription)")
        }

        guard let top = root as? [String: Any] else {
            throw VaultVerseError.invalidInput("This doesn't look like a Music/iTunes \"Export Library…\" file.")
        }
        guard let rawTracks = top["Tracks"] as? [String: Any],
              let rawPlaylists = top["Playlists"] as? [[String: Any]] else {
            throw VaultVerseError.invalidInput("This doesn't look like a Music/iTunes \"Export Library…\" file (no Tracks/Playlists).")
        }

        let tracksById = buildTracks(rawTracks)
        let entries = buildPlaylists(rawPlaylists, tracksById: tracksById)
        let catalog = tracksById
            .sorted { $0.key < $1.key }
            .map(\.value)

        return ParsedLibrary(profile: makeProfile(), playlists: entries, catalog: catalog)
    }

    // MARK: - Tracks

    private static func buildTracks(_ raw: [String: Any]) -> [Int: ProviderTrack] {
        var out: [Int: ProviderTrack] = [:]
        for (key, value) in raw {
            guard let dict = value as? [String: Any] else { continue }
            guard let trackId = int(dict, "Track ID") ?? Int(key) else { continue }
            guard let name = string(dict, "Name") else { continue }   // a track with no name is unusable

            let artist = string(dict, "Artist") ?? "Unknown Artist"
            out[trackId] = ProviderTrack(
                providerTrackId: String(trackId),
                providerURI: string(dict, "Location"),        // file:// path — used to build re-importable .m3u
                title: name,
                artistName: artist,
                artists: [artist],
                albumName: string(dict, "Album"),
                durationMs: int(dict, "Total Time"),          // iTunes stores Total Time in milliseconds
                isrc: nil,                                     // not present in Library.xml
                releaseDate: date(dict, "Release Date"),
                explicit: nil,
                artworkURL: nil,
                addedAt: date(dict, "Date Added"),
                availability: .available,
                rawPayload: rawJSON(dict)
            )
        }
        return out
    }

    // MARK: - Playlists (order preserved; system/auto playlists skipped)

    private static func buildPlaylists(_ raw: [[String: Any]], tracksById: [Int: ProviderTrack]) -> [ParsedLibrary.Entry] {
        var entries: [ParsedLibrary.Entry] = []
        for dict in raw {
            // Skip the auto/system playlists Music exports (Library, Music, Downloaded, …).
            if bool(dict, "Master") || dict["Distinguished Kind"] != nil { continue }
            guard let name = string(dict, "Name") else { continue }

            let items = (dict["Playlist Items"] as? [[String: Any]]) ?? []
            let tracks = items.compactMap { item -> ProviderTrack? in
                guard let id = int(item, "Track ID") else { return nil }
                return tracksById[id]
            }

            let id = string(dict, "Playlist Persistent ID")
                ?? int(dict, "Playlist ID").map(String.init)
                ?? UUID().uuidString
            let playlist = ProviderPlaylist(
                providerPlaylistId: id,
                name: name,
                description: nil,
                ownerName: nil,
                artworkURL: nil,
                isPublic: false,
                trackCount: tracks.count
            )
            entries.append(ParsedLibrary.Entry(playlist: playlist, tracks: tracks))
        }
        return entries
    }

    // MARK: - Profile

    private static func makeProfile() -> ProviderUserProfile {
        let name = NSFullUserName().isEmpty ? "Apple Music export" : NSFullUserName()
        return ProviderUserProfile(providerUserId: "library-xml", displayName: name, storefront: nil)
    }

    // MARK: - Typed plist accessors

    private static func string(_ d: [String: Any], _ key: String) -> String? {
        guard let value = d[key] as? String, !value.isEmpty else { return nil }
        return value
    }

    private static func int(_ d: [String: Any], _ key: String) -> Int? {
        if let n = d[key] as? Int { return n }
        if let n = d[key] as? NSNumber { return n.intValue }
        return nil
    }

    private static func bool(_ d: [String: Any], _ key: String) -> Bool {
        (d[key] as? Bool) ?? false
    }

    private static func date(_ d: [String: Any], _ key: String) -> Date? {
        d[key] as? Date
    }

    /// Re-serialize a track dict to JSON for verbatim archival. Plist `Date`s are
    /// normalized to ISO-8601 strings so `JSONSerialization` can encode them.
    private static func rawJSON(_ dict: [String: Any]) -> String? {
        let safe = jsonSafe(dict)
        guard JSONSerialization.isValidJSONObject(safe),
              let data = try? JSONSerialization.data(withJSONObject: safe, options: [.sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func jsonSafe(_ value: Any) -> Any {
        switch value {
        case let date as Date:
            return ISO8601DateFormatter().string(from: date)
        case let dict as [String: Any]:
            return dict.mapValues(jsonSafe)
        case let array as [Any]:
            return array.map(jsonSafe)
        case let string as String:
            return string
        case let number as NSNumber:
            return number
        default:
            return String(describing: value)
        }
    }
}
