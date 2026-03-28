import Foundation
import FaceBridgeCore

public struct AuthorizationResponse: Sendable {
    public static let minimumSignatureSize = 64

    public let requestId: UUID
    public let version: ProtocolVersion
    public let responderDeviceId: UUID
    public let decision: AuthorizationDecision
    public let signature: Data
    public let signedPayload: Data
    public let respondedAt: Date

    public init(
        requestId: UUID,
        version: ProtocolVersion = .current,
        responderDeviceId: UUID,
        decision: AuthorizationDecision,
        signature: Data,
        signedPayload: Data,
        respondedAt: Date = Date()
    ) throws {
        guard signature.count >= Self.minimumSignatureSize else {
            throw FaceBridgeError.verificationFailed(detail: "Signature too short: \(signature.count) bytes")
        }
        guard !signedPayload.isEmpty else {
            throw FaceBridgeError.payloadIntegrityMismatch
        }
        self.requestId = requestId
        self.version = version
        self.responderDeviceId = responderDeviceId
        self.decision = decision
        self.signature = signature
        self.signedPayload = signedPayload
        self.respondedAt = respondedAt
    }
}

extension AuthorizationResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case requestId, version, responderDeviceId, decision, signature, signedPayload, respondedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            requestId: container.decode(UUID.self, forKey: .requestId),
            version: container.decode(ProtocolVersion.self, forKey: .version),
            responderDeviceId: container.decode(UUID.self, forKey: .responderDeviceId),
            decision: container.decode(AuthorizationDecision.self, forKey: .decision),
            signature: container.decode(Data.self, forKey: .signature),
            signedPayload: container.decode(Data.self, forKey: .signedPayload),
            respondedAt: container.decode(Date.self, forKey: .respondedAt)
        )
    }
}

public enum AuthorizationDecision: String, Codable, Sendable {
    case approved
    case denied
    case expired
    case error
}
