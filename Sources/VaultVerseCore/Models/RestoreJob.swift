import Foundation

/// Tracks one restore of a playlist snapshot into a target provider.
public struct RestoreJob: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var playlistId: String
    public var snapshotId: String
    public var targetProvider: Provider
    public var targetConnectedAccountId: String?
    public var status: JobStatus
    public var totalTracks: Int
    public var matchedTracks: Int
    public var unmatchedTracks: Int
    public var failedTracks: Int
    public var createdTargetPlaylistId: String?
    public var createdTargetPlaylistName: String?
    public var errors: [JobError]
    public var startedAt: Date
    public var completedAt: Date?

    public init(
        id: String = UUID().uuidString,
        playlistId: String,
        snapshotId: String,
        targetProvider: Provider,
        targetConnectedAccountId: String? = nil,
        status: JobStatus = .pending,
        totalTracks: Int = 0,
        matchedTracks: Int = 0,
        unmatchedTracks: Int = 0,
        failedTracks: Int = 0,
        createdTargetPlaylistId: String? = nil,
        createdTargetPlaylistName: String? = nil,
        errors: [JobError] = [],
        startedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.playlistId = playlistId
        self.snapshotId = snapshotId
        self.targetProvider = targetProvider
        self.targetConnectedAccountId = targetConnectedAccountId
        self.status = status
        self.totalTracks = totalTracks
        self.matchedTracks = matchedTracks
        self.unmatchedTracks = unmatchedTracks
        self.failedTracks = failedTracks
        self.createdTargetPlaylistId = createdTargetPlaylistId
        self.createdTargetPlaylistName = createdTargetPlaylistName
        self.errors = errors
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}
