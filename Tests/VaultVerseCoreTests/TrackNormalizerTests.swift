import Testing
@testable import VaultVerseCore

@Suite("Track normalization")
struct TrackNormalizerTests {
    @Test("Strips (feat. …) from titles")
    func stripsFeaturing() {
        #expect(TrackNormalizer.normalizeTitle("Levitating (feat. DaBaby)") == "levitating")
        #expect(TrackNormalizer.normalizeTitle("Peaches (feat. Daniel Caesar & Giveon)") == "peaches")
    }

    @Test("Removes bracketed edition noise")
    func removesEditionNoise() {
        #expect(TrackNormalizer.normalizeTitle("Bohemian Rhapsody (Remastered 2011)") == "bohemian rhapsody")
        #expect(TrackNormalizer.normalizeTitle("Dreams [Radio Edit]") == "dreams")
        #expect(TrackNormalizer.normalizeTitle("Thriller (Deluxe Edition)") == "thriller")
    }

    @Test("Lowercases and strips punctuation, keeps digits")
    func punctuationAndDigits() {
        #expect(TrackNormalizer.normalizeTitle("good 4 u") == "good 4 u")
        #expect(TrackNormalizer.normalizeTitle("Don't Stop Me Now!") == "dont stop me now")
    }

    @Test("Normalizes ampersand to 'and'")
    func ampersand() {
        #expect(TrackNormalizer.normalizeTitle("Earth & Fire") == "earth and fire")
    }

    @Test("Artist: folds diacritics, drops featuring")
    func artistNormalization() {
        #expect(TrackNormalizer.normalizeArtist("Beyoncé") == "beyonce")
        #expect(TrackNormalizer.normalizeArtist("Dua Lipa feat. DaBaby") == "dua lipa")
        #expect(TrackNormalizer.normalizeArtist("The Weeknd") == "the weeknd")
    }

    @Test("Preserves materially-different variants")
    func preservesMeaningfulVariants() {
        // "live"/"acoustic"/"remix" change the recording — must NOT be stripped.
        #expect(TrackNormalizer.normalizeTitle("Hurt (Live)") == "hurt live")
        #expect(TrackNormalizer.normalizeTitle("Closer (Acoustic)") == "closer acoustic")
    }
}
