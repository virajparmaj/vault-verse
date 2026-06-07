import Foundation

/// A user's connection to a music provider.
///
/// SECURITY: no tokens are stored on this struct. The Music User Token and any
/// `.p8` reference live only in the Keychain (see `KeychainStore`); this record
/// holds only a non-sensitive pointer (`tokenKeychainRef`) and is safe to export.
public struct ConnectedAccount: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var provider: Provider
    public var providerUserId: String?
    public var displayName: String?
    public var scopes: [String]
    public var storefront: String?
    public var status: ConnectionStatus
    /// Opaque Keychain account key for the token material — never the token itself.
    public var tokenKeychainRef: String?
    public var connectedAt: Date
    public var lastUsedAt: Date?

    public init(
        id: String = UUID().uuidString,
        provider: Provider,
        providerUserId: String? = nil,
        displayName: String? = nil,
        scopes: [String] = [],
        storefront: String? = nil,
        status: ConnectionStatus = .connected,
        tokenKeychainRef: String? = nil,
        connectedAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.provider = provider
        self.providerUserId = providerUserId
        self.displayName = displayName
        self.scopes = scopes
        self.storefront = storefront
        self.status = status
        self.tokenKeychainRef = tokenKeychainRef
        self.connectedAt = connectedAt
        self.lastUsedAt = lastUsedAt
    }
}

public enum ConnectionStatus: String, Codable, Sendable, Hashable {
    case connected
    case disconnected
    case expired
    case error
}
