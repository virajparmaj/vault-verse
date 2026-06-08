import Foundation

/// Which connector backs the app's import/restore flows. VaultVerse is local-first:
/// both options run entirely on this Mac with no account and no MusicKit.
enum LibrarySource: String, CaseIterable, Identifiable {
    /// Built-in realistic sample data — zero setup.
    case demo
    /// The user's real library, parsed from a Music "Export Library…" `.xml`.
    case appleMusicExport

    var id: String { rawValue }

    var title: String {
        switch self {
        case .demo: return "Demo library"
        case .appleMusicExport: return "Apple Music export (.xml)"
        }
    }

    var detail: String {
        switch self {
        case .demo: return "Realistic sample data — nothing to set up."
        case .appleMusicExport: return "Your real library from a Music \u{201C}Export Library\u{2026}\u{201D} file."
        }
    }
}

/// Tiny persistence for the chosen source (the app has no other settings store).
enum LibrarySourceStore {
    private static let key = "vaultverse.librarySource"

    static func load() -> LibrarySource {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let source = LibrarySource(rawValue: raw) else {
            return .demo
        }
        return source
    }

    static func save(_ source: LibrarySource) {
        UserDefaults.standard.set(source.rawValue, forKey: key)
    }
}
