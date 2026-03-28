import Foundation
import CoreBluetooth
import os
import FaceBridgeCore
import FaceBridgeProtocol

public final class BLETransport: NSObject, Transport, @unchecked Sendable {
    public static let serviceUUID = CBUUID(string: "FB10FACE-B1D6-4A3E-9F00-000000000001")
    public static let characteristicUUID = CBUUID(string: "FB10FACE-B1D6-4A3E-9F00-000000000002")
    public static let maxReceiveSize = 65_536

    public let transportType: TransportType = .ble

    private struct MutableState {
        var connectionStates: [UUID: ConnectionState] = [:]
        var discoveredPeripherals: [UUID: CBPeripheral] = [:]
        var connectedPeripherals: [UUID: CBPeripheral] = [:]
        var centralManager: CBCentralManager?
        var peripheralManager: CBPeripheralManager?
        var authorizedPeers: Set<UUID> = []
    }

    private let state = OSAllocatedUnfairLock(initialState: MutableState())
    private let encoder = MessageEncoder()
    private let fragmentationManager = BLEFragmentationManager()
    private let queue = DispatchQueue(label: "com.facebridge.ble", qos: .userInitiated)

    public weak var delegate: TransportDelegate?

    public var connectionState: ConnectionState {
        state.withLock { s in
            if s.connectedPeripherals.isEmpty { return .disconnected }
            return .connected
        }
    }

    public func connectionState(for deviceId: UUID) -> ConnectionState {
        state.withLock { $0.connectionStates[deviceId] ?? .disconnected }
    }

    public override init() {
        super.init()
    }

    public func authorizePeer(_ deviceId: UUID) {
        _ = state.withLock { $0.authorizedPeers.insert(deviceId) }
    }

    public func deauthorizePeer(_ deviceId: UUID) {
        _ = state.withLock { $0.authorizedPeers.remove(deviceId) }
    }

    public func startDiscovery() {
        let manager = CBCentralManager(delegate: self, queue: queue)
        state.withLock { $0.centralManager = manager }
    }

    public func stopDiscovery() {
        state.withLock { $0.centralManager?.stopScan() }
    }

    public func connect(to deviceId: UUID) async throws {
        try state.withLock { s in
            guard let peripheral = s.discoveredPeripherals[deviceId] else {
                throw FaceBridgeError.transportUnavailable
            }
            s.connectionStates[deviceId] = .connecting
            s.centralManager?.connect(peripheral)
        }
    }

    public func disconnect(from deviceId: UUID) async throws {
        state.withLock { s in
            guard let peripheral = s.connectedPeripherals[deviceId] else { return }
            s.connectionStates[deviceId] = .disconnecting
            s.centralManager?.cancelPeripheralConnection(peripheral)
        }
    }

    public func send(_ envelope: MessageEnvelope, to deviceId: UUID) async throws {
        let data = try encoder.encodeEnvelope(envelope)
        let fragments = await fragmentationManager.fragment(data)

        try state.withLock { s in
            guard let peripheral = s.connectedPeripherals[deviceId] else {
                throw FaceBridgeError.transportUnavailable
            }
            guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }),
                  let characteristic = service.characteristics?.first(where: { $0.uuid == Self.characteristicUUID })
            else {
                throw FaceBridgeError.transportUnavailable
            }
            for fragment in fragments {
                peripheral.writeValue(fragment, for: characteristic, type: .withResponse)
            }
        }
    }

    public func startAdvertising(displayName: String) {
        let manager = CBPeripheralManager(delegate: self, queue: queue)
        state.withLock { $0.peripheralManager = manager }
    }
}

extension BLETransport: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        central.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let device = DiscoveredDevice(
            id: peripheral.identifier,
            displayName: peripheral.name ?? "Unknown",
            rssi: RSSI.intValue,
            transportType: .ble
        )
        state.withLock { $0.discoveredPeripherals[peripheral.identifier] = peripheral }
        delegate?.transport(self, didDiscover: device)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        state.withLock { s in
            s.connectionStates[peripheral.identifier] = .connected
            s.connectedPeripherals[peripheral.identifier] = peripheral
        }
        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID])
        delegate?.transport(self, didConnect: peripheral.identifier)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        state.withLock { s in
            s.connectionStates[peripheral.identifier] = .disconnected
            s.connectedPeripherals.removeValue(forKey: peripheral.identifier)
        }
        delegate?.transport(self, didDisconnect: peripheral.identifier)
    }
}

extension BLETransport: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else { return }
        peripheral.discoverCharacteristics([Self.characteristicUUID], for: service)
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == Self.characteristicUUID }) else { return }
        peripheral.setNotifyValue(true, for: characteristic)
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        let isAuthorized = state.withLock { $0.authorizedPeers.contains(peripheral.identifier) }
        guard isAuthorized else {
            delegate?.transport(self, didFailWithError: .untrustedDevice)
            return
        }
        guard data.count <= Self.maxReceiveSize else {
            delegate?.transport(self, didFailWithError: .messageTooLarge(size: data.count, max: Self.maxReceiveSize))
            return
        }

        Task { [weak self] in
            guard let self else { return }
            guard let reassembled = await self.fragmentationManager.reassemble(data) else { return }
            do {
                let envelope = try self.encoder.decodeEnvelope(from: reassembled)
                self.delegate?.transport(self, didReceive: envelope, from: peripheral.identifier)
            } catch {
                self.delegate?.transport(self, didFailWithError: .decodingFailed)
            }
        }
    }
}

extension BLETransport: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else { return }
        let characteristic = CBMutableCharacteristic(
            type: Self.characteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readEncryptionRequired, .writeEncryptionRequired]
        )
        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [characteristic]
        peripheral.add(service)
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
        ])
    }
}
