import Foundation

/// All errors surfaced by VaultVerse core. User-facing copy lives in
/// `errorDescription` so the UI can show it directly.
public enum VaultVerseError: Error, LocalizedError, Sendable, Hashable {
    /// The live provider has no usable credentials configured yet.
    case providerNotConfigured(Provider)
    /// The user denied authorization for the provider (e.g. MusicKit prompt).
    case authorizationDenied(Provider)
    /// A live code path that is intentionally stubbed for the first pass.
    case notImplemented(String)
    case authenticationFailed(String)
    case authExpired(Provider)
    case accessRevoked(Provider)
    case rateLimited(retryAfterSeconds: Double?)
    case playlistNotFound(String)
    case snapshotNotFound(String)
    case restoreJobNotFound(String)
    case unmatchedTrackNotFound(String)
    case trackNotFound(String)
    case regionUnavailable(String)
    case seedDataMissing(String)
    case decodingFailed(String)
    case persistenceFailure(String)
    case exportFailed(String)
    case invalidInput(String)
    /// A previously imported library file can no longer be reached on launch
    /// (moved, deleted, on an unmounted volume, or its saved access went stale).
    case libraryAccessUnavailable

    public var errorDescription: String? {
        switch self {
        case .providerNotConfigured(let p):
            return "\(p.displayName) isn't configured yet. Add credentials in Settings to use the live connection."
        case .authorizationDenied(let p):
            return "VaultVerse needs permission to access your \(p.displayName) library. Open System Settings → Privacy & Security → Media & Apple Music to grant access."
        case .notImplemented(let what):
            return "Not available in this build: \(what)."
        case .authenticationFailed(let why):
            return "Couldn't connect: \(why)"
        case .authExpired(let p):
            return "Your \(p.displayName) session expired. Reconnect to continue."
        case .accessRevoked(let p):
            return "VaultVerse's access to \(p.displayName) was revoked. Reconnect to continue."
        case .rateLimited(let retry):
            if let retry { return "Rate limited. Try again in about \(Int(retry))s." }
            return "Rate limited. Please try again shortly."
        case .playlistNotFound(let id):
            return "Playlist not found (\(id))."
        case .snapshotNotFound(let id):
            return "Snapshot not found (\(id))."
        case .restoreJobNotFound(let id):
            return "Restore job not found (\(id))."
        case .unmatchedTrackNotFound(let id):
            return "Unmatched track not found (\(id))."
        case .trackNotFound(let id):
            return "Track not found (\(id))."
        case .regionUnavailable(let title):
            return "\"\(title)\" isn't available in your storefront."
        case .seedDataMissing(let detail):
            return "Demo data could not be loaded: \(detail)"
        case .decodingFailed(let detail):
            return "Could not read data: \(detail)"
        case .persistenceFailure(let detail):
            return "Storage error: \(detail)"
        case .exportFailed(let detail):
            return "Export failed: \(detail)"
        case .invalidInput(let detail):
            return "Invalid input: \(detail)"
        case .libraryAccessUnavailable:
            return "VaultVerse can't reach your imported Apple Music library anymore. Re-import it from Connections to keep it loaded after relaunch."
        }
    }
}
