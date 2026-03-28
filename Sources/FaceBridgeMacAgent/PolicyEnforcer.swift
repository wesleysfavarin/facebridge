import Foundation
import FaceBridgeCore

public actor PolicyEnforcer {
    private var policy: AuthorizationPolicy
    private let auditLogger: AuditLogger

    public init(policy: AuthorizationPolicy = .default, auditLogger: AuditLogger = AuditLogger()) {
        self.policy = policy
        self.auditLogger = auditLogger
    }

    public func updatePolicy(_ newPolicy: AuthorizationPolicy) {
        policy = newPolicy
    }

    public func enforce(session: Session, rssi: Int? = nil) async -> PolicyDecision {
        let engine = PolicyEngine(policy: policy)
        let decision = engine.evaluate(session: session, rssi: rssi)

        if case .denied(let reason) = decision {
            await auditLogger.log(
                .authorizationDenied,
                sessionId: session.id,
                details: "Policy enforcement: \(reason.rawValue)"
            )
        }

        return decision
    }
}
