import Foundation

/// Maps a normalized `Track` to a specific provider's catalog entry.
///
/// A single `Track` can have many mappings (one per provider, sometimes per
/// storefront). Manual corrections are stored here with `isManualOverride = true`
/// so VaultVerse "remembers forever" and reuses them on every future restore.
public struct TrackPlatformMapping: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var trackId: String
    public var provider: Provider
    public var providerTrackId: String
    public var providerURI: String?
    public var providerURL: String?
    public var catalogCountry: String?
    public var matchMethod: MatchMethod
    /// 0–100. See `TrackMatchingService`. Anything below 80 needs review.
    public var confidenceScore: Int
    public var isManualOverride: Bool
    public var availabilityStatus: AvailabilityStatus
    public var lastVerifiedAt: Date?
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        trackId: String,
        provider: Provider,
        providerTrackId: String,
        providerURI: String? = nil,
        providerURL: String? = nil,
        catalogCountry: String? = nil,
        matchMethod: MatchMethod,
        confidenceScore: Int,
        isManualOverride: Bool = false,
        availabilityStatus: AvailabilityStatus = .unknown,
        lastVerifiedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.trackId = trackId
        self.provider = provider
        self.providerTrackId = providerTrackId
        self.providerURI = providerURI
        self.providerURL = providerURL
        self.catalogCountry = catalogCountry
        self.matchMethod = matchMethod
        self.confidenceScore = confidenceScore
        self.isManualOverride = isManualOverride
        self.availabilityStatus = availabilityStatus
        self.lastVerifiedAt = lastVerifiedAt
        self.createdAt = createdAt
    }

    /// Mappings at or above this score are safe to restore without review.
    public static let confidentThreshold = 80
}
