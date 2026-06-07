import Testing
@testable import VaultVerseCore

@Suite("Track matching")
struct TrackMatchingServiceTests {
    private func track(title: String, artist: String, album: String? = nil, durationMs: Int? = nil, isrc: String? = nil) -> Track {
        Track(
            title: title,
            normalizedTitle: TrackNormalizer.normalizeTitle(title),
            primaryArtist: artist,
            artists: [artist],
            normalizedArtist: TrackNormalizer.normalizeArtist(artist),
            album: album,
            durationMs: durationMs,
            isrc: isrc
        )
    }

    private func candidate(title: String, artist: String, album: String? = nil, durationMs: Int? = nil, isrc: String? = nil, id: String = "c1", availability: AvailabilityStatus = .available) -> ProviderTrackSearchResult {
        ProviderTrackSearchResult(providerTrackId: id, title: title, artistName: artist, albumName: album, durationMs: durationMs, isrc: isrc, availability: availability)
    }

    @Test("Exact ISRC → 100 even when the title differs")
    func isrcExact() {
        let match = TrackMatchingService.score(
            track: track(title: "Song", artist: "Artist", isrc: "USABC1234567"),
            candidate: candidate(title: "Song (Remastered 2019)", artist: "Artist", isrc: "usabc1234567")
        )
        #expect(match.score == 100)
        #expect(match.method == .isrc)
    }

    @Test("Title + artist + duration (±3s) → 95")
    func titleArtistDuration() {
        let match = TrackMatchingService.score(
            track: track(title: "Blinding Lights", artist: "The Weeknd", durationMs: 200040),
            candidate: candidate(title: "Blinding Lights", artist: "The Weeknd", durationMs: 201500)
        )
        #expect(match.score == 95)
        #expect(match.method == .titleArtistDuration)
    }

    @Test("Title + artist + album → 90 when duration is off")
    func titleArtistAlbum() {
        let match = TrackMatchingService.score(
            track: track(title: "Song", artist: "Artist", album: "Album", durationMs: 200000),
            candidate: candidate(title: "Song", artist: "Artist", album: "Album", durationMs: 240000)
        )
        #expect(match.score == 90)
        #expect(match.method == .titleArtistAlbum)
    }

    @Test("Title + artist + duration (±10s) → 85 when album differs")
    func titleArtistDurationClose() {
        let match = TrackMatchingService.score(
            track: track(title: "Song", artist: "Artist", album: "A", durationMs: 200000),
            candidate: candidate(title: "Song", artist: "Artist", album: "B", durationMs: 208000)
        )
        #expect(match.score == 85)
        #expect(match.method == .titleArtistDurationClose)
    }

    @Test("Genuinely different title → fuzzy, below the confident bands")
    func fuzzy() {
        let match = TrackMatchingService.score(
            track: track(title: "A Bar Song (Tipsy)", artist: "Shaboozey"),
            candidate: candidate(title: "Tipsy", artist: "Shaboozey")
        )
        #expect(match.method == .fuzzy)
        #expect(match.score < 85)
    }

    @Test("bestMatch picks the strongest candidate")
    func bestMatch() {
        let weak = candidate(title: "Song (Live)", artist: "Artist", id: "weak")
        let strong = candidate(title: "Song", artist: "Artist", durationMs: 200000, isrc: "USABC1234567", id: "strong")
        let best = TrackMatchingService.bestMatch(
            for: track(title: "Song", artist: "Artist", durationMs: 200000, isrc: "USABC1234567"),
            in: [weak, strong]
        )
        #expect(best?.candidate.providerTrackId == "strong")
        #expect(best?.score == 100)
    }
}
