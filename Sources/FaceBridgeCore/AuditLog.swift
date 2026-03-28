import Foundation

public struct AuditEntry: Codable, Sendable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let event: AuditEvent
    public let deviceId: UUID?
    public let sessionId: UUID?
    public let details: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        event: AuditEvent,
        deviceId: UUID? = nil,
        sessionId: UUID? = nil,
        details: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.deviceId = deviceId
        self.sessionId = sessionId
        self.details = details
    }
}

public enum AuditEvent: String, Codable, Sendable {
    case pairingInitiated
    case pairingCompleted
    case pairingFailed
    case pairingRejected
    case deviceRevoked
    case keyRotated
    case authorizationRequested
    case authorizationApproved
    case authorizationDenied
    case signatureVerificationFailed
    case sessionExpired
    case replayDetected
    case agentStarted
    case agentStopped
}

public actor AuditLogger {
    private var entries: [AuditEntry] = []
    private let maxEntries: Int

    public init(maxEntries: Int = 10_000) {
        self.maxEntries = maxEntries
    }

    public func log(_ event: AuditEvent, deviceId: UUID? = nil, sessionId: UUID? = nil, details: String? = nil) {
        let entry = AuditEntry(
            event: event,
            deviceId: deviceId,
            sessionId: sessionId,
            details: details
        )
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    public func allEntries() -> [AuditEntry] {
        entries
    }

    public func entries(for event: AuditEvent) -> [AuditEntry] {
        entries.filter { $0.event == event }
    }

    public func entries(since date: Date) -> [AuditEntry] {
        entries.filter { $0.timestamp >= date }
    }

    public func clear() {
        entries.removeAll()
    }
}
