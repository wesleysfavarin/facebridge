import Foundation

public struct Session: Codable, Hashable, Sendable {
    public let id: UUID
    public let trustRelationshipId: UUID
    public let nonce: Nonce
    public let createdAt: Date
    public let expiresAt: Date
    public private(set) var state: SessionState

    public var isExpired: Bool { Date() > expiresAt }

    public init(
        id: UUID = UUID(),
        trustRelationshipId: UUID,
        nonce: Nonce,
        createdAt: Date = Date(),
        ttl: TimeInterval = 30
    ) {
        self.id = id
        self.trustRelationshipId = trustRelationshipId
        self.nonce = nonce
        self.createdAt = createdAt
        self.expiresAt = createdAt.addingTimeInterval(ttl)
        self.state = .pending
    }

    public mutating func approve() {
        guard !isExpired else { return }
        state = .approved
    }

    public mutating func deny() {
        state = .denied
    }

    public mutating func expire() {
        state = .expired
    }
}

public enum SessionState: String, Codable, Hashable, Sendable {
    case pending
    case approved
    case denied
    case expired
}
