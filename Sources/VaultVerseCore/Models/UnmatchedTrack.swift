import Foundation

/// A track that could not be confidently mapped during a restore preflight and
/// needs human review. Carries suggestions so the user can pick the right match.
public struct UnmatchedTrack: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var restoreJobId: String
    public var trackId: String
    public var title: String
    public var artist: String
    public var album: String?
    public var durationMs: Int?
    public var attemptedProvider: Provider
    public var reason: String
    public var suggestedMatches: [SuggestedMatch]
    public var userSelectedMappingId: String?
    public var resolvedAt: Date?
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        restoreJobId: String,
        trackId: String,
        title: String,
        artist: String,
        album: String? = nil,
        durationMs: Int? = nil,
        attemptedProvider: Provider,
        reason: String,
        suggestedMatches: [SuggestedMatch] = [],
        userSelectedMappingId: String? = nil,
        resolvedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.restoreJobId = restoreJobId
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.album = album
        self.durationMs = durationMs
        self.attemptedProvider = attemptedProvider
        self.reason = reason
        self.suggestedMatches = suggestedMatches
        self.userSelectedMappingId = userSelectedMappingId
        self.resolvedAt = resolvedAt
        self.createdAt = createdAt
    }
}

/// A candidate catalog match offered to the user when resolving an unmatched track.
public struct SuggestedMatch: Codable, Identifiable, Hashable, Sendable {
    public var id: String { providerTrackId }
    public var provider: Provider
    public var providerTrackId: String
    public var providerURI: String?
    public var title: String
    public var artist: String
    public var album: String?
    public var durationMs: Int?
    public var confidenceScore: Int
    public var matchMethod: MatchMethod
    public var availability: AvailabilityStatus

    public init(
        provider: Provider,
        providerTrackId: String,
        providerURI: String? = nil,
        title: String,
        artist: String,
        album: String? = nil,
        durationMs: Int? = nil,
        confidenceScore: Int,
        matchMethod: MatchMethod,
        availability: AvailabilityStatus = .unknown
    ) {
        self.provider = provider
        self.providerTrackId = providerTrackId
        self.providerURI = providerURI
        self.title = title
        self.artist = artist
        self.album = album
        self.durationMs = durationMs
        self.confidenceScore = confidenceScore
        self.matchMethod = matchMethod
        self.availability = availability
    }
}
