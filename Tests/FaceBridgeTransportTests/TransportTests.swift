import Testing
import Foundation
@testable import FaceBridgeTransport
@testable import FaceBridgeProtocol
@testable import FaceBridgeCore

@Suite("ConnectionManager")
struct ConnectionManagerTests {
    @Test("register and track transports")
    func registerTransport() async {
        let manager = ConnectionManager()
        let mock = MockTransport(type: .ble)
        await manager.register(mock)

        let connected = await manager.connectedDeviceIds()
        #expect(connected.isEmpty)
    }
}

@Suite("DiscoveredDevice")
struct DiscoveredDeviceTests {
    @Test("equality")
    func equality() {
        let id = UUID()
        let date = Date()
        let a = DiscoveredDevice(id: id, displayName: "A", rssi: -50, transportType: .ble, lastSeen: date)
        let b = DiscoveredDevice(id: id, displayName: "A", rssi: -50, transportType: .ble, lastSeen: date)
        #expect(a == b)
    }

    @Test("different ids are not equal")
    func differentIds() {
        let a = DiscoveredDevice(id: UUID(), displayName: "A", rssi: -50, transportType: .ble)
        let b = DiscoveredDevice(id: UUID(), displayName: "A", rssi: -50, transportType: .ble)
        #expect(a != b)
    }
}

final class MockTransport: Transport, @unchecked Sendable {
    let transportType: TransportType
    var connectionState: ConnectionState = .disconnected
    weak var delegate: TransportDelegate?

    init(type: TransportType) {
        self.transportType = type
    }

    func startDiscovery() {}
    func stopDiscovery() {}

    func connect(to deviceId: UUID) async throws {
        connectionState = .connected
    }

    func disconnect(from deviceId: UUID) async throws {
        connectionState = .disconnected
    }

    func send(_ envelope: MessageEnvelope, to deviceId: UUID) async throws {}
}
