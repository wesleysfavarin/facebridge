import Foundation
import FaceBridgeCore

public struct AuthorizationRequest: Codable, Sendable {
    public let id: UUID
    public let version: ProtocolVersion
    public let senderDeviceId: UUID
    public let nonce: Data
    public let challenge: Data
    public let reason: String
    public let createdAt: Date
    public let expiresAt: Date

    public var isExpired: Bool { Date() > expiresAt }

    public init(
        id: UUID = UUID(),
        version: ProtocolVersion = .current,
        senderDeviceId: UUID,
        nonce: Data,
        challenge: Data,
        reason: String,
        createdAt: Date = Date(),
        ttl: TimeInterval = 30
    ) {
        self.id = id
        self.version = version
        self.senderDeviceId = senderDeviceId
        self.nonce = nonce
        self.challenge = challenge
        self.reason = reason
        self.createdAt = createdAt
        self.expiresAt = createdAt.addingTimeInterval(ttl)
    }

    public var signable: Data {
        var payload = Data()
        payload.append(id.uuidString.data(using: .utf8)!)
        payload.append(nonce)
        payload.append(challenge)
        payload.append(reason.data(using: .utf8)!)

        var timestamp = createdAt.timeIntervalSince1970
        payload.append(Data(bytes: &timestamp, count: MemoryLayout<TimeInterval>.size))

        return payload
    }
}
