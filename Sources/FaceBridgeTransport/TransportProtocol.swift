import Foundation
import FaceBridgeCore
import FaceBridgeProtocol

public enum TransportType: String, Sendable {
    case ble
    case localNetwork
}

public enum ConnectionState: String, Sendable {
    case disconnected
    case connecting
    case connected
    case disconnecting
}

public struct DiscoveredDevice: Sendable, Hashable {
    public let id: UUID
    public let displayName: String
    public let rssi: Int
    public let transportType: TransportType
    public let lastSeen: Date

    public init(id: UUID, displayName: String, rssi: Int, transportType: TransportType, lastSeen: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.rssi = rssi
        self.transportType = transportType
        self.lastSeen = lastSeen
    }
}

public protocol TransportDelegate: AnyObject, Sendable {
    func transport(_ transport: any Transport, didDiscover device: DiscoveredDevice)
    func transport(_ transport: any Transport, didConnect deviceId: UUID)
    func transport(_ transport: any Transport, didDisconnect deviceId: UUID)
    func transport(_ transport: any Transport, didReceive envelope: MessageEnvelope, from deviceId: UUID)
    func transport(_ transport: any Transport, didFailWithError error: FaceBridgeError)
}

public protocol Transport: AnyObject, Sendable {
    var transportType: TransportType { get }
    var connectionState: ConnectionState { get }
    var delegate: TransportDelegate? { get set }

    func startDiscovery()
    func stopDiscovery()
    func connect(to deviceId: UUID) async throws
    func disconnect(from deviceId: UUID) async throws
    func send(_ envelope: MessageEnvelope, to deviceId: UUID) async throws
}
