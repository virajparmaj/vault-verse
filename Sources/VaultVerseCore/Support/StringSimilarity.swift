import Foundation

/// String similarity metrics for fuzzy track matching. Pure and deterministic.
public enum StringSimilarity {

    /// Levenshtein edit distance.
    public static func levenshtein(_ a: String, _ b: String) -> Int {
        let s = Array(a), t = Array(b)
        if s.isEmpty { return t.count }
        if t.isEmpty { return s.count }
        var previous = Array(0...t.count)
        var current = [Int](repeating: 0, count: t.count + 1)
        for i in 1...s.count {
            current[0] = i
            for j in 1...t.count {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[t.count]
    }

    /// Normalized Levenshtein similarity in 0...1.
    public static func levenshteinRatio(_ a: String, _ b: String) -> Double {
        if a.isEmpty && b.isEmpty { return 1 }
        let distance = levenshtein(a, b)
        return 1.0 - Double(distance) / Double(max(a.count, b.count))
    }

    /// Jaro–Winkler similarity in 0...1 (rewards a common prefix; good for names).
    public static func jaroWinkler(_ a: String, _ b: String) -> Double {
        let jaro = self.jaro(a, b)
        let s = Array(a), t = Array(b)
        var prefix = 0
        for i in 0..<min(4, min(s.count, t.count)) {
            if s[i] == t[i] { prefix += 1 } else { break }
        }
        return jaro + Double(prefix) * 0.1 * (1 - jaro)
    }

    private static func jaro(_ a: String, _ b: String) -> Double {
        let s = Array(a), t = Array(b)
        if s.isEmpty && t.isEmpty { return 1 }
        if s.isEmpty || t.isEmpty { return 0 }
        let matchDistance = max(s.count, t.count) / 2 - 1
        var sMatches = [Bool](repeating: false, count: s.count)
        var tMatches = [Bool](repeating: false, count: t.count)
        var matches = 0
        for i in 0..<s.count {
            let start = max(0, i - matchDistance)
            let end = min(i + matchDistance + 1, t.count)
            if start >= end { continue }
            for j in start..<end where !tMatches[j] && s[i] == t[j] {
                sMatches[i] = true
                tMatches[j] = true
                matches += 1
                break
            }
        }
        if matches == 0 { return 0 }
        var transpositions = 0
        var k = 0
        for i in 0..<s.count where sMatches[i] {
            while !tMatches[k] { k += 1 }
            if s[i] != t[k] { transpositions += 1 }
            k += 1
        }
        let m = Double(matches)
        return (m / Double(s.count) + m / Double(t.count) + (m - Double(transpositions) / 2) / m) / 3
    }

    /// Blended title/name similarity used by the matcher. Averages Jaro–Winkler
    /// (typo/prefix tolerant) and Levenshtein ratio (length-difference aware) so
    /// neither dominates.
    public static func blended(_ a: String, _ b: String) -> Double {
        (jaroWinkler(a, b) + levenshteinRatio(a, b)) / 2
    }
}
