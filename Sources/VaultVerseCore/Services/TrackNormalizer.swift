import Foundation

/// Pure, deterministic title/artist normalization used everywhere a fuzzy
/// comparison is needed (mock catalog search, matching, dedup).
///
/// Goal: collapse cosmetic differences ("Song (Remastered 2011)" vs "Song")
/// without destroying meaning. Anything material to identity — live, acoustic,
/// remix, "Taylor's Version" — is deliberately preserved.
public enum TrackNormalizer {

    /// Edition descriptors that are noise for matching, per the product spec.
    static let editionKeywords: [String] = [
        "remastered", "remaster", "deluxe edition", "deluxe", "explicit",
        "clean", "radio edit", "single version", "album version",
        "bonus track", "expanded edition", "special edition",
        "anniversary edition", "mono", "stereo"
    ]

    static let featKeywords = ["feat", "ft", "featuring", "remaster", "remastered",
                               "deluxe", "explicit", "clean", "radio edit",
                               "single version", "album version", "bonus track",
                               "expanded edition", "special edition",
                               "anniversary edition"]

    public static func normalizeTitle(_ raw: String) -> String {
        var s = fold(raw)
        s = removeNoisyParentheticals(s)
        // Drop an un-bracketed trailing "feat./ft./featuring …".
        s = s.replacingOccurrences(
            of: "\\b(feat|ft|featuring)\\.?\\s.*$",
            with: " ",
            options: [.regularExpression]
        )
        // Remove leftover edition keywords appearing outside brackets.
        for kw in editionKeywords {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: kw) + "\\b"
            s = s.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression])
        }
        return stripAndCollapse(s)
    }

    public static func normalizeArtist(_ raw: String) -> String {
        var s = fold(raw)
        s = s.replacingOccurrences(
            of: "\\b(feat|ft|featuring)\\.?\\s.*$",
            with: " ",
            options: [.regularExpression]
        )
        return stripAndCollapse(s)
    }

    // MARK: - Helpers

    private static func fold(_ raw: String) -> String {
        raw.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")).lowercased()
    }

    private static func removeNoisyParentheticals(_ s: String) -> String {
        let kw = featKeywords.joined(separator: "|")
        let pattern = "[\\(\\[][^\\)\\]]*\\b(\(kw))\\b[^\\)\\]]*[\\)\\]]"
        return s.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
    }

    /// Apostrophes/quotes are deleted (not spaced) so contractions join:
    /// "Don't" → "dont". Everything else non-alphanumeric becomes a separator.
    private static let deletedScalars = CharacterSet(charactersIn: "'\u{2019}\u{2018}`\u{02BC}\u{00B4}")

    private static func stripAndCollapse(_ s: String) -> String {
        let withAnd = s.replacingOccurrences(of: "&", with: " and ")
        var out = String.UnicodeScalarView()
        for scalar in withAnd.unicodeScalars {
            if deletedScalars.contains(scalar) { continue }
            if CharacterSet.alphanumerics.contains(scalar) || scalar == " " {
                out.append(scalar)
            } else {
                out.append(" ")
            }
        }
        let collapsed = String(out).replacingOccurrences(of: "\\s+", with: " ", options: [.regularExpression])
        return collapsed.trimmingCharacters(in: .whitespaces)
    }
}
