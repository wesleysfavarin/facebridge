import Foundation
import FaceBridgeCore

public struct AuthorizationRequest: Codable, Sendable {
    public let id: UUID
    public let version: ProtocolVersion
    public let senderDeviceId: UUID
    public let nonce: Data
    public let challenge: Data
    public let reason: String
    public let transportType: String
    public let createdAt: Date
    public let expiresAt: Date
    /// Sender's signature over signable, proving request origin
    public let senderSignature: Data?

    public var isExpired: Bool { Date() > expiresAt }

    public init(
        id: UUID = UUID(),
        version: ProtocolVersion = .current,
        senderDeviceId: UUID,
        nonce: Data,
        challenge: Data,
        reason: String,
        transportType: String = "unknown",
        createdAt: Date = Date(),
        ttl: TimeInterval = 30,
        senderSignature: Data? = nil
    ) {
        self.id = id
        self.version = version
        self.senderDeviceId = senderDeviceId
        self.nonce = nonce
        self.challenge = challenge
        self.reason = reason
        self.transportType = transportType
        self.createdAt = createdAt
        self.expiresAt = createdAt.addingTimeInterval(ttl)
        self.senderSignature = senderSignature
    }

    /// Canonical length-prefixed binary payload for signing.
    public var signable: Data {
        var payload = Data()
        func appendField(_ data: Data) {
            var length = UInt32(data.count).bigEndian
            payload.append(Data(bytes: &length, count: 4))
            payload.append(data)
        }
        appendField(Data(id.uuidString.utf8))
        appendField(Data(version.description.utf8))
        appendField(Data(senderDeviceId.uuidString.utf8))
        appendField(nonce)
        appendField(challenge)
        appendField(Data(reason.utf8))
        appendField(Data(transportType.utf8))
        var timestamp = UInt64(createdAt.timeIntervalSince1970 * 1000).bigEndian
        let tsData = Data(bytes: &timestamp, count: 8)
        appendField(tsData)
        return payload
    }

}
