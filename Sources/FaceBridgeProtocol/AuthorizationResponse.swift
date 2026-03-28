import Foundation
import FaceBridgeCore

public struct AuthorizationResponse: Codable, Sendable {
    public let requestId: UUID
    public let version: ProtocolVersion
    public let responderDeviceId: UUID
    public let decision: AuthorizationDecision
    public let signature: Data?
    public let signedPayload: Data?
    public let respondedAt: Date

    public init(
        requestId: UUID,
        version: ProtocolVersion = .current,
        responderDeviceId: UUID,
        decision: AuthorizationDecision,
        signature: Data? = nil,
        signedPayload: Data? = nil,
        respondedAt: Date = Date()
    ) {
        self.requestId = requestId
        self.version = version
        self.responderDeviceId = responderDeviceId
        self.decision = decision
        self.signature = signature
        self.signedPayload = signedPayload
        self.respondedAt = respondedAt
    }
}

public enum AuthorizationDecision: String, Codable, Sendable {
    case approved
    case denied
    case expired
    case error
}
