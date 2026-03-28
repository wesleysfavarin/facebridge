import Foundation
import FaceBridgeCore
import FaceBridgeProtocol
import FaceBridgeTransport

public actor BackgroundListener {
    public enum ListenerState: Sendable {
        case stopped
        case listening
        case processing
    }

    private let connectionManager: ConnectionManager
    private let auditLogger: AuditLogger
    public private(set) var state: ListenerState = .stopped

    private var pendingRequests: [UUID: AuthorizationRequest] = [:]

    public init(connectionManager: ConnectionManager, auditLogger: AuditLogger = AuditLogger()) {
        self.connectionManager = connectionManager
        self.auditLogger = auditLogger
    }

    public func start() async {
        state = .listening
        await connectionManager.startDiscovery()
    }

    public func stop() async {
        state = .stopped
        await connectionManager.stopDiscovery()
    }

    public func enqueue(_ request: AuthorizationRequest) {
        guard !request.isExpired else { return }
        pendingRequests[request.id] = request
        state = .processing
    }

    public func dequeue(_ requestId: UUID) -> AuthorizationRequest? {
        let request = pendingRequests.removeValue(forKey: requestId)
        if pendingRequests.isEmpty {
            state = .listening
        }
        return request
    }

    public func pendingRequestCount() -> Int {
        pendingRequests.count
    }
}
