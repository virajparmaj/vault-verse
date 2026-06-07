import Foundation

/// Codable mirror of `Resources/SeedData/apple_music_library.json`. Internal —
/// the mock connector consumes it and re-exposes provider-neutral DTOs.
struct SeedLibrary: Codable {
    let profile: SeedProfile
    let playlists: [SeedPlaylist]
    let catalogTweaks: SeedCatalogTweaks?

    /// Applies authored catalog discrepancies so restore preflight is realistic
    /// (e.g. a fuzzy variant that forces a "needs review" outcome).
    func applyCatalogTweaks(to catalog: [ProviderTrack]) -> [ProviderTrack] {
        guard let variants = catalogTweaks?.fuzzyVariants, !variants.isEmpty else { return catalog }
        var result = catalog
        for variant in variants {
            result.removeAll { $0.providerTrackId == variant.replacesTrackId }
            result.append(variant.providerTrack())
        }
        return result
    }

    static func loadDefault(bundle: Bundle = .module) throws -> SeedLibrary {
        guard let url = locate(in: bundle) else {
            throw VaultVerseError.seedDataMissing("apple_music_library.json not found in resource bundle")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SeedLibrary.self, from: data)
        } catch let error as VaultVerseError {
            throw error
        } catch {
            throw VaultVerseError.decodingFailed("seed library: \(error.localizedDescription)")
        }
    }

    private static func locate(in bundle: Bundle) -> URL? {
        if let url = bundle.url(forResource: "apple_music_library", withExtension: "json") { return url }
        if let url = bundle.url(forResource: "apple_music_library", withExtension: "json", subdirectory: "SeedData") { return url }
        if let url = bundle.url(forResource: "apple_music_library", withExtension: "json", subdirectory: "Resources/SeedData") { return url }
        return bundle.urls(forResourcesWithExtension: "json", subdirectory: nil)?
            .first { $0.lastPathComponent == "apple_music_library.json" }
    }

    func providerModel() -> (profile: ProviderUserProfile, playlists: [(ProviderPlaylist, [ProviderTrack])]) {
        let prof = ProviderUserProfile(
            providerUserId: profile.providerUserId,
            displayName: profile.displayName,
            storefront: profile.storefront
        )
        let pls = playlists.map { sp -> (ProviderPlaylist, [ProviderTrack]) in
            let tracks = sp.tracks.map { $0.providerTrack() }
            let pp = ProviderPlaylist(
                providerPlaylistId: sp.providerPlaylistId,
                name: sp.name,
                description: sp.description,
                ownerName: sp.ownerName,
                artworkURL: sp.artworkURL,
                isPublic: sp.isPublic,
                trackCount: tracks.count
            )
            return (pp, tracks)
        }
        return (prof, pls)
    }
}

struct SeedProfile: Codable {
    let providerUserId: String
    let displayName: String?
    let storefront: String?
}

struct SeedPlaylist: Codable {
    let providerPlaylistId: String
    let name: String
    let description: String?
    let ownerName: String?
    let artworkURL: String?
    let isPublic: Bool
    let tracks: [SeedTrack]
}

struct SeedTrack: Codable {
    let providerTrackId: String
    let providerURI: String?
    let title: String
    let artistName: String
    let artists: [String]
    let albumName: String?
    let durationMs: Int?
    let isrc: String?
    let releaseDate: String?
    let explicit: Bool?
    let artworkURL: String?
    let addedAt: String?
    let availability: String?

    func providerTrack() -> ProviderTrack {
        ProviderTrack(
            providerTrackId: providerTrackId,
            providerURI: providerURI,
            title: title,
            artistName: artistName,
            artists: artists,
            albumName: albumName,
            durationMs: durationMs,
            isrc: isrc,
            releaseDate: SeedDate.day(releaseDate),
            explicit: explicit,
            artworkURL: artworkURL,
            addedAt: SeedDate.iso(addedAt),
            availability: AvailabilityStatus(rawValue: availability ?? "available") ?? .available,
            rawPayload: rawJSON()
        )
    }

    private func rawJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct SeedCatalogTweaks: Codable {
    let fuzzyVariants: [SeedFuzzyVariant]?
}

struct SeedFuzzyVariant: Codable {
    let replacesTrackId: String
    let providerTrackId: String
    let providerURI: String?
    let title: String
    let artistName: String
    let albumName: String?
    let durationMs: Int?
    let isrc: String?
    let availability: String?

    func providerTrack() -> ProviderTrack {
        ProviderTrack(
            providerTrackId: providerTrackId,
            providerURI: providerURI,
            title: title,
            artistName: artistName,
            artists: [artistName],
            albumName: albumName,
            durationMs: durationMs,
            isrc: isrc,
            availability: AvailabilityStatus(rawValue: availability ?? "available") ?? .available,
            rawPayload: nil
        )
    }
}

enum SeedDate {
    static let day: @Sendable (String?) -> Date? = { value in
        guard let value, !value.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    static let iso: @Sendable (String?) -> Date? = { value in
        guard let value, !value.isEmpty else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }
}
