import Foundation

public struct SessionToken: Codable, Sendable, Hashable {
    public let value: String
    public let sessionId: UUID
    public let issuedAt: Date
    public let expiresAt: Date

    public var isExpired: Bool { Date() > expiresAt }

    public init(
        sessionId: UUID,
        issuedAt: Date = Date(),
        ttl: TimeInterval = 30
    ) {
        self.value = UUID().uuidString
        self.sessionId = sessionId
        self.issuedAt = issuedAt
        self.expiresAt = issuedAt.addingTimeInterval(ttl)
    }
}
