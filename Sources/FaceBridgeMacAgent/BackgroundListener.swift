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
    private var deviceRequestCounts: [UUID: (count: Int, windowStart: Date)] = [:]

    private let maxQueueSize: Int
    private let maxRequestsPerDevice: Int
    private let rateLimitWindow: TimeInterval

    public init(
        connectionManager: ConnectionManager,
        auditLogger: AuditLogger = AuditLogger(),
        maxQueueSize: Int = 50,
        maxRequestsPerDevice: Int = 10,
        rateLimitWindow: TimeInterval = 60
    ) {
        self.connectionManager = connectionManager
        self.auditLogger = auditLogger
        self.maxQueueSize = maxQueueSize
        self.maxRequestsPerDevice = maxRequestsPerDevice
        self.rateLimitWindow = rateLimitWindow
    }

    public func start() async {
        state = .listening
        await connectionManager.startDiscovery()
    }

    public func stop() async {
        state = .stopped
        await connectionManager.stopDiscovery()
    }

    public enum EnqueueResult: Sendable {
        case accepted
        case rejected(FaceBridgeError)
    }

    public func enqueue(_ request: AuthorizationRequest) async -> EnqueueResult {
        guard !request.isExpired else { return .rejected(.sessionExpired) }

        guard pendingRequests.count < maxQueueSize else {
            await auditLogger.log(.authorizationDenied, deviceId: request.senderDeviceId, details: "Queue overflow")
            return .rejected(.queueOverflow)
        }

        let now = Date()
        var record = deviceRequestCounts[request.senderDeviceId] ?? (count: 0, windowStart: now)
        if now.timeIntervalSince(record.windowStart) > rateLimitWindow {
            record = (count: 0, windowStart: now)
        }
        guard record.count < maxRequestsPerDevice else {
            await auditLogger.log(.authorizationDenied, deviceId: request.senderDeviceId, details: "Rate limited")
            return .rejected(.rateLimited)
        }

        record.count += 1
        deviceRequestCounts[request.senderDeviceId] = record

        pendingRequests[request.id] = request
        state = .processing
        return .accepted
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

    private var lastProcessingStart: Date?
    private let stuckTimeout: TimeInterval = 120

    public func pruneExpired() {
        let expired = pendingRequests.filter { $0.value.isExpired }.map(\.key)
        for id in expired {
            pendingRequests.removeValue(forKey: id)
        }
        if pendingRequests.isEmpty && state == .processing {
            state = .listening
            lastProcessingStart = nil
        }
    }

    public func recoverIfStuck() {
        guard state == .processing else {
            lastProcessingStart = nil
            return
        }
        let now = Date()
        if let start = lastProcessingStart {
            if now.timeIntervalSince(start) > stuckTimeout {
                pendingRequests.removeAll()
                state = .listening
                lastProcessingStart = nil
            }
        } else {
            lastProcessingStart = now
        }
    }
}
