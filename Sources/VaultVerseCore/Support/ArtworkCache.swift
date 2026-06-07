import Foundation

/// Content-addressed on-disk cache for playlist/track artwork.
///
/// VaultVerse stores artwork *references* (URLs) in the vault and only ever
/// caches images — never audio. Caching is best-effort: the import pipeline does
/// not block on it, so an offline import still succeeds (just without thumbnails
/// until the next online view).
public actor ArtworkCache {
    private let directory: URL
    private let fileManager = FileManager.default

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = caches.appendingPathComponent("VaultVerse/Artwork", isDirectory: true)
        }
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    public func localURL(forRemote remoteURL: String) -> URL {
        let key = Checksum.sha256Hex(remoteURL)
        let ext = URL(string: remoteURL)?.pathExtension ?? ""
        return directory.appendingPathComponent(ext.isEmpty ? key : "\(key).\(ext)")
    }

    public func cachedFile(forRemote remoteURL: String) -> URL? {
        let url = localURL(forRemote: remoteURL)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    /// Returns a local file URL, downloading once if not already cached.
    @discardableResult
    public func fetch(remoteURL: String) async throws -> URL {
        if let cached = cachedFile(forRemote: remoteURL) { return cached }
        guard let url = URL(string: remoteURL), url.scheme?.hasPrefix("http") == true else {
            throw VaultVerseError.invalidInput("artwork URL: \(remoteURL)")
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let destination = localURL(forRemote: remoteURL)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    public func clear() throws {
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
