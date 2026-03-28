import Foundation
import FaceBridgeCore
import FaceBridgeProtocol

public actor ConnectionManager {
    private var transports: [TransportType: any Transport] = [:]
    private var activeConnections: [UUID: TransportType] = [:]

    public init() {}

    public func register(_ transport: any Transport) {
        transports[transport.transportType] = transport
    }

    public func startDiscovery() {
        for transport in transports.values {
            transport.startDiscovery()
        }
    }

    public func stopDiscovery() {
        for transport in transports.values {
            transport.stopDiscovery()
        }
    }

    public func connect(to deviceId: UUID, via type: TransportType) async throws {
        guard let transport = transports[type] else {
            throw FaceBridgeError.transportUnavailable
        }
        try await transport.connect(to: deviceId)
        activeConnections[deviceId] = type
    }

    public func disconnect(from deviceId: UUID) async throws {
        guard let type = activeConnections[deviceId],
              let transport = transports[type] else { return }
        try await transport.disconnect(from: deviceId)
        activeConnections.removeValue(forKey: deviceId)
    }

    public func send(_ envelope: MessageEnvelope, to deviceId: UUID) async throws {
        guard let type = activeConnections[deviceId],
              let transport = transports[type] else {
            throw FaceBridgeError.transportUnavailable
        }
        try await transport.send(envelope, to: deviceId)
    }

    public func connectedDeviceIds() -> Set<UUID> {
        Set(activeConnections.keys)
    }
}
