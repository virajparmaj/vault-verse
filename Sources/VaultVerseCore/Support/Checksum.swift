import Foundation
import CryptoKit

/// Stable content hashing used for snapshot checksums and artwork cache keys.
public enum Checksum {
    public static func sha256Hex(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
