import Foundation

/// Scores how well a catalog candidate matches a stored track, on a 0–100 scale.
///
/// Ladder (first strong signal wins):
///   1. Exact ISRC                         → 100
///   2. Title + artist + duration (±3s)    → 95
///   3. Title + artist + album             → 90
///   4. Title + artist + duration (±10s)   → 85
///   5. Fuzzy title + artist               → up to 84
/// Manual overrides are applied by the restore service, not here, and always win.
public enum TrackMatchingService {
    public static let confidentThreshold = 80
    /// Best score in [reviewThreshold, confidentThreshold) → needs human review.
    public static let reviewThreshold = 60

    public struct Match: Sendable, Hashable {
        public let candidate: ProviderTrackSearchResult
        public let score: Int
        public let method: MatchMethod

        public init(candidate: ProviderTrackSearchResult, score: Int, method: MatchMethod) {
            self.candidate = candidate
            self.score = score
            self.method = method
        }
    }

    public static func bestMatch(
        for track: Track,
        in candidates: [ProviderTrackSearchResult],
        highToleranceMs: Int = 3000,
        mediumToleranceMs: Int = 10000
    ) -> Match? {
        let scored = candidates.map {
            score(track: track, candidate: $0, highToleranceMs: highToleranceMs, mediumToleranceMs: mediumToleranceMs)
        }
        return scored.max { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            // Tie-break: prefer an available candidate.
            let lhsAvailable = lhs.candidate.availability == .available
            let rhsAvailable = rhs.candidate.availability == .available
            return !lhsAvailable && rhsAvailable
        }
    }

    public static func score(
        track: Track,
        candidate: ProviderTrackSearchResult,
        highToleranceMs: Int = 3000,
        mediumToleranceMs: Int = 10000
    ) -> Match {
        // 1. ISRC
        if let a = track.isrc, let b = candidate.isrc, !a.isEmpty, !b.isEmpty,
           a.caseInsensitiveCompare(b) == .orderedSame {
            return Match(candidate: candidate, score: 100, method: .isrc)
        }

        let titleExact = track.normalizedTitle == TrackNormalizer.normalizeTitle(candidate.title)
        let artistExact = track.normalizedArtist == TrackNormalizer.normalizeArtist(candidate.artistName)

        if titleExact && artistExact {
            // 2. duration within ±3s
            if durationClose(track.durationMs, candidate.durationMs, highToleranceMs) {
                return Match(candidate: candidate, score: 95, method: .titleArtistDuration)
            }
            // 3. album match
            if albumMatch(track.album, candidate.albumName) {
                return Match(candidate: candidate, score: 90, method: .titleArtistAlbum)
            }
            // 4. duration within ±10s
            if durationClose(track.durationMs, candidate.durationMs, mediumToleranceMs) {
                return Match(candidate: candidate, score: 85, method: .titleArtistDurationClose)
            }
        }

        // 5. Fuzzy (capped below the confident-via-exact bands).
        let titleSim = StringSimilarity.blended(track.normalizedTitle, TrackNormalizer.normalizeTitle(candidate.title))
        let artistSim = StringSimilarity.blended(track.normalizedArtist, TrackNormalizer.normalizeArtist(candidate.artistName))
        let combined = 0.6 * titleSim + 0.4 * artistSim
        let fuzzy = min(84, max(0, Int((combined * 100).rounded())))
        return Match(candidate: candidate, score: fuzzy, method: .fuzzy)
    }

    // MARK: - Helpers

    static func durationClose(_ a: Int?, _ b: Int?, _ tolerance: Int) -> Bool {
        guard let a, let b else { return false }
        return abs(a - b) <= tolerance
    }

    static func albumMatch(_ a: String?, _ b: String?) -> Bool {
        guard let a, let b, !a.isEmpty, !b.isEmpty else { return false }
        return TrackNormalizer.normalizeTitle(a) == TrackNormalizer.normalizeTitle(b)
    }
}
