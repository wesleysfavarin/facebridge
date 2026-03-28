import Foundation
import FaceBridgeCore
import FaceBridgeCrypto
import FaceBridgeProtocol

public actor AuthorizationResponder {
    private let authenticator: BiometricAuthenticator
    private let keyManager: KeyManaging
    private let trustManager: DeviceTrustManager
    private let auditLogger: AuditLogger
    private let replayProtector: ReplayProtector

    public init(
        authenticator: BiometricAuthenticator = BiometricAuthenticator(),
        keyManager: KeyManaging,
        trustManager: DeviceTrustManager,
        auditLogger: AuditLogger = AuditLogger(),
        replayProtector: ReplayProtector = ReplayProtector()
    ) {
        self.authenticator = authenticator
        self.keyManager = keyManager
        self.trustManager = trustManager
        self.auditLogger = auditLogger
        self.replayProtector = replayProtector
    }

    public func respond(to request: AuthorizationRequest, keyTag: String) async throws -> AuthorizationResponse {
        guard !request.isExpired else {
            await auditLogger.log(.sessionExpired, sessionId: request.id)
            return AuthorizationResponse(
                requestId: request.id,
                responderDeviceId: UUID(),
                decision: .expired
            )
        }

        guard await trustManager.isTrusted(request.senderDeviceId) else {
            await auditLogger.log(.authorizationDenied, deviceId: request.senderDeviceId, details: "Untrusted device")
            throw FaceBridgeError.untrustedDevice
        }

        let nonce = Nonce(value: request.nonce, createdAt: request.createdAt)
        guard await replayProtector.validate(nonce) else {
            await auditLogger.log(.replayDetected, sessionId: request.id)
            throw FaceBridgeError.replayDetected
        }

        let authenticated = try await authenticator.authenticate(reason: request.reason)

        guard authenticated else {
            await auditLogger.log(.authorizationDenied, sessionId: request.id)
            return AuthorizationResponse(
                requestId: request.id,
                responderDeviceId: UUID(),
                decision: .denied
            )
        }

        let payload = request.signable
        let signature = try keyManager.sign(data: payload, keyTag: keyTag)

        await auditLogger.log(.authorizationApproved, sessionId: request.id)

        return AuthorizationResponse(
            requestId: request.id,
            responderDeviceId: UUID(),
            decision: .approved,
            signature: signature,
            signedPayload: payload
        )
    }
}
