import Foundation
import FaceBridgeCore

public actor SecureSessionHandler {
    private var activeSessions: [UUID: Session] = [:]
    private let replayProtector: ReplayProtector
    private let auditLogger: AuditLogger

    public init(replayProtector: ReplayProtector = ReplayProtector(), auditLogger: AuditLogger = AuditLogger()) {
        self.replayProtector = replayProtector
        self.auditLogger = auditLogger
    }

    public func createSession(trustRelationshipId: UUID, ttl: TimeInterval = 30) -> Session {
        let nonce = NonceGenerator().generate()
        let session = Session(trustRelationshipId: trustRelationshipId, nonce: nonce, ttl: ttl)
        activeSessions[session.id] = session
        return session
    }

    public func session(for id: UUID) -> Session? {
        activeSessions[id]
    }

    public func validateAndConsume(_ sessionId: UUID) async -> Session? {
        guard var session = activeSessions[sessionId] else { return nil }

        guard !session.isExpired else {
            session.expire()
            activeSessions[sessionId] = session
            await auditLogger.log(.sessionExpired, sessionId: sessionId)
            return nil
        }

        let valid = await replayProtector.validate(session.nonce)
        guard valid else {
            await auditLogger.log(.replayDetected, sessionId: sessionId)
            return nil
        }

        return session
    }

    public func approveSession(_ sessionId: UUID) {
        activeSessions[sessionId]?.approve()
    }

    public func denySession(_ sessionId: UUID) {
        activeSessions[sessionId]?.deny()
    }

    public func removeSession(_ sessionId: UUID) {
        activeSessions.removeValue(forKey: sessionId)
    }

    public func pruneExpired() async {
        for (id, session) in activeSessions where session.isExpired {
            activeSessions[id]?.expire()
            await auditLogger.log(.sessionExpired, sessionId: id)
        }
    }
}
