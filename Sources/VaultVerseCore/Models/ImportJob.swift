import Foundation

/// Tracks one run of importing/syncing playlists from a provider.
public struct ImportJob: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var provider: Provider
    public var connectedAccountId: String?
    public var status: JobStatus
    public var totalPlaylistsFound: Int
    public var playlistsImported: Int
    public var snapshotsCreated: Int
    public var tracksImported: Int
    public var errors: [JobError]
    public var startedAt: Date
    public var completedAt: Date?

    public init(
        id: String = UUID().uuidString,
        provider: Provider,
        connectedAccountId: String? = nil,
        status: JobStatus = .pending,
        totalPlaylistsFound: Int = 0,
        playlistsImported: Int = 0,
        snapshotsCreated: Int = 0,
        tracksImported: Int = 0,
        errors: [JobError] = [],
        startedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.provider = provider
        self.connectedAccountId = connectedAccountId
        self.status = status
        self.totalPlaylistsFound = totalPlaylistsFound
        self.playlistsImported = playlistsImported
        self.snapshotsCreated = snapshotsCreated
        self.tracksImported = tracksImported
        self.errors = errors
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}
