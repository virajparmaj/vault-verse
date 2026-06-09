import Foundation
import VaultVerseCore

/// Persists *read access* to the user-picked Music "Export Library…" `.xml` across
/// launches using a security-scoped bookmark, so VaultVerse can re-open the real
/// library next launch without making the user pick the file again.
///
/// Stored in `UserDefaults` beside `LibrarySource` (`LibrarySourceStore`) — the
/// app's only settings store. The companion to that type: `LibrarySourceStore`
/// remembers *which* source is active, this remembers *how to reach* the file
/// backing the `.appleMusicExport` source.
enum LibraryBookmarkStore {
    private static let key = "vaultverse.appleMusicExport.bookmark"
    private static var defaults: UserDefaults { .standard }

    /// Capture and persist a security-scoped bookmark for `url`. Throws a
    /// `VaultVerseError` if the OS won't vend one; callers treat that as a soft
    /// warning — the import itself still succeeded, it just won't auto-reload.
    static func save(for url: URL) throws {
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(data, forKey: key)
        } catch {
            throw VaultVerseError.persistenceFailure(
                "couldn't remember access to your imported library — you may need to re-import after relaunch (\(error.localizedDescription))"
            )
        }
    }

    /// Resolve the stored bookmark back to a URL, or `nil` when none is stored
    /// (no real library has been imported yet — a normal, not-an-error state).
    ///
    /// `isStale` is propagated so the caller can refresh the bookmark after a
    /// successful read. Throws `VaultVerseError.libraryAccessUnavailable` when a
    /// bookmark exists but can no longer be resolved (deleted, unmounted, denied).
    static func resolve() throws -> (url: URL, isStale: Bool)? {
        guard let data = defaults.data(forKey: key) else { return nil }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return (url, isStale)
        } catch {
            throw VaultVerseError.libraryAccessUnavailable
        }
    }
}
