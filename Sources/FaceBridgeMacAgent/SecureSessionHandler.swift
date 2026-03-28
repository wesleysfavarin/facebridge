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

    public func createSession(trustRelationshipId: UUID, ttl: TimeInterval = 30) throws -> Session {
        let nonce = try NonceGenerator().generate()
        let session = Session(trustRelationshipId: trustRelationshipId, nonce: nonce, ttl: ttl)
        activeSessions[session.id] = session
        return session
    }

    public func session(for id: UUID) -> Session? {
        activeSessions[id]
    }

    public func validateAndConsume(_ sessionId: UUID) async -> Session? {
        guard let session = activeSessions.removeValue(forKey: sessionId) else { return nil }

        guard !session.isExpired else {
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

    public func approveAndConsume(_ sessionId: UUID) throws -> Session? {
        guard var session = activeSessions.removeValue(forKey: sessionId) else { return nil }
        try session.approve()
        return session
    }

    public func denyAndConsume(_ sessionId: UUID) throws -> Session? {
        guard var session = activeSessions.removeValue(forKey: sessionId) else { return nil }
        try session.deny()
        return session
    }

    public func removeSession(_ sessionId: UUID) {
        activeSessions.removeValue(forKey: sessionId)
    }

    public func activeSessionCount() -> Int {
        activeSessions.count
    }

    public func pruneExpired() async {
        var expired: [UUID] = []
        for (id, session) in activeSessions where session.isExpired {
            expired.append(id)
        }
        for id in expired {
            activeSessions.removeValue(forKey: id)
            await auditLogger.log(.sessionExpired, sessionId: id)
        }
    }
}
