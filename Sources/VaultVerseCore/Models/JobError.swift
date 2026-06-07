import Foundation

/// A single, non-fatal failure recorded during an import or restore.
///
/// Per the product rule, one bad playlist or track must never abort an entire
/// job — the failure is captured here and the job continues.
public struct JobError: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    /// What the error is about, e.g. "playlist", "track", "auth".
    public var scope: String
    /// Identifier of the offending item, when known.
    public var itemIdentifier: String?
    public var message: String
    public let occurredAt: Date

    public init(
        id: String = UUID().uuidString,
        scope: String,
        itemIdentifier: String? = nil,
        message: String,
        occurredAt: Date = Date()
    ) {
        self.id = id
        self.scope = scope
        self.itemIdentifier = itemIdentifier
        self.message = message
        self.occurredAt = occurredAt
    }
}
