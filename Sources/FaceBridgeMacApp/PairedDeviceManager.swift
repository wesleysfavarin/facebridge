import Foundation
import FaceBridgeCore
import FaceBridgeCrypto

public actor PairedDeviceManager {
    private let keychainStore: SecureStorage
    private let auditLogger: AuditLogger
    private var pairedDevices: [UUID: DeviceIdentity] = [:]

    private static let storageKey = "com.facebridge.mac.paired-devices"

    public init(keychainStore: SecureStorage = KeychainStore(), auditLogger: AuditLogger = AuditLogger()) {
        self.keychainStore = keychainStore
        self.auditLogger = auditLogger
    }

    public func loadPairedDevices() throws {
        guard let data = try keychainStore.load(for: Self.storageKey) else { return }
        let devices = try JSONDecoder().decode([DeviceIdentity].self, from: data)
        pairedDevices = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
    }

    public func addPairedDevice(_ device: DeviceIdentity) throws {
        pairedDevices[device.id] = device
        try persistDevices()
        Task { await auditLogger.log(.pairingCompleted, deviceId: device.id) }
    }

    public func removePairedDevice(_ deviceId: UUID) throws {
        pairedDevices.removeValue(forKey: deviceId)
        try persistDevices()
        Task { await auditLogger.log(.deviceRevoked, deviceId: deviceId) }
    }

    public func isPaired(_ deviceId: UUID) -> Bool {
        pairedDevices[deviceId] != nil
    }

    public func device(for id: UUID) -> DeviceIdentity? {
        pairedDevices[id]
    }

    public func allPairedDevices() -> [DeviceIdentity] {
        Array(pairedDevices.values)
    }

    public func publicKey(for deviceId: UUID) -> Data? {
        pairedDevices[deviceId]?.publicKeyData
    }

    private func persistDevices() throws {
        let data = try JSONEncoder().encode(Array(pairedDevices.values))
        try keychainStore.save(data: data, for: Self.storageKey)
    }
}
