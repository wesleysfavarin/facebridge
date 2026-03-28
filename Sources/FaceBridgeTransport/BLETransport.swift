import Foundation
import CoreBluetooth
import FaceBridgeCore
import FaceBridgeProtocol

public final class BLETransport: NSObject, Transport, @unchecked Sendable {
    public static let serviceUUID = CBUUID(string: "FB10FACE-B1D6-4A3E-9F00-000000000001")
    public static let characteristicUUID = CBUUID(string: "FB10FACE-B1D6-4A3E-9F00-000000000002")

    public let transportType: TransportType = .ble
    public private(set) var connectionState: ConnectionState = .disconnected
    public weak var delegate: TransportDelegate?

    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var connectedPeripherals: [UUID: CBPeripheral] = [:]
    private let encoder = MessageEncoder()

    private let queue = DispatchQueue(label: "com.facebridge.ble", qos: .userInitiated)

    public override init() {
        super.init()
    }

    public func startDiscovery() {
        centralManager = CBCentralManager(delegate: self, queue: queue)
    }

    public func stopDiscovery() {
        centralManager?.stopScan()
    }

    public func connect(to deviceId: UUID) async throws {
        guard let peripheral = discoveredPeripherals[deviceId] else {
            throw FaceBridgeError.transportUnavailable
        }
        connectionState = .connecting
        centralManager?.connect(peripheral)
    }

    public func disconnect(from deviceId: UUID) async throws {
        guard let peripheral = connectedPeripherals[deviceId] else { return }
        connectionState = .disconnecting
        centralManager?.cancelPeripheralConnection(peripheral)
    }

    public func send(_ envelope: MessageEnvelope, to deviceId: UUID) async throws {
        guard let peripheral = connectedPeripherals[deviceId] else {
            throw FaceBridgeError.transportUnavailable
        }

        let data = try encoder.encodeEnvelope(envelope)

        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }),
              let characteristic = service.characteristics?.first(where: { $0.uuid == Self.characteristicUUID })
        else {
            throw FaceBridgeError.transportUnavailable
        }

        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    public func startAdvertising(displayName: String) {
        peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
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
        discoveredPeripherals[peripheral.identifier] = peripheral
        delegate?.transport(self, didDiscover: device)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionState = .connected
        connectedPeripherals[peripheral.identifier] = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID])
        delegate?.transport(self, didConnect: peripheral.identifier)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionState = .disconnected
        connectedPeripherals.removeValue(forKey: peripheral.identifier)
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
        do {
            let envelope = try encoder.decodeEnvelope(from: data)
            delegate?.transport(self, didReceive: envelope, from: peripheral.identifier)
        } catch {
            delegate?.transport(self, didFailWithError: .decodingFailed)
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
            permissions: [.readable, .writeable]
        )

        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [characteristic]

        peripheral.add(service)
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
        ])
    }
}
