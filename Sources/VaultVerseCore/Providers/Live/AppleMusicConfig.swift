import Foundation

/// Configuration for the *live* Apple Music connection.
///
/// None of this is required for the first pass (the app runs on the mock). These
/// fields exist so wiring real MusicKit later is a config change, not a rewrite.
///
/// SECURITY: the `.p8` private key and any generated developer token are secrets.
/// They must come from Keychain / a secure config file — never hard-coded, never
/// logged, never shipped in the app bundle.
public struct AppleMusicConfig: Sendable, Hashable {
    /// Apple Developer Team ID (10 chars), e.g. "A1B2C3D4E5".
    public var teamID: String
    /// MusicKit private key ID (the Key ID of the `.p8`), e.g. "ABC123DEFG".
    public var keyID: String
    /// Filesystem path or Keychain ref to the `AuthKey_<KeyID>.p8` private key.
    public var privateKeyP8Path: String
    /// Optional pre-generated developer token (ES256 JWT). If nil, the live
    /// service is expected to mint one from the `.p8` server-side.
    public var developerToken: String?
    /// Apple Music storefront (country) code, e.g. "us", "gb", "in".
    public var storefront: String

    public init(
        teamID: String = "",
        keyID: String = "",
        privateKeyP8Path: String = "",
        developerToken: String? = nil,
        storefront: String = "us"
    ) {
        self.teamID = teamID
        self.keyID = keyID
        self.privateKeyP8Path = privateKeyP8Path
        self.developerToken = developerToken
        self.storefront = storefront
    }

    /// True only when enough is present to attempt a live developer token.
    public var isConfigured: Bool {
        !teamID.isEmpty && !keyID.isEmpty && (!privateKeyP8Path.isEmpty || (developerToken?.isEmpty == false))
    }

    public static let unconfigured = AppleMusicConfig()
}
