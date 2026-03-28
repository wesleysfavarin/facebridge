import Foundation
import FaceBridgeCore
import FaceBridgeCrypto

public actor DeviceTrustManager {
    private let keychainStore: SecureStorage
    private let auditLogger: AuditLogger
    private var trustedDevices: [UUID: DeviceIdentity] = [:]

    private static let storageKey = "com.facebridge.trusted-devices"

    public init(keychainStore: SecureStorage = KeychainStore(), auditLogger: AuditLogger = AuditLogger()) {
        self.keychainStore = keychainStore
        self.auditLogger = auditLogger
    }

    public func loadTrustedDevices() throws {
        guard let data = try keychainStore.load(for: Self.storageKey) else { return }
        let devices = try JSONDecoder().decode([DeviceIdentity].self, from: data)
        trustedDevices = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
    }

    public func addTrustedDevice(_ device: DeviceIdentity) async throws {
        trustedDevices[device.id] = device
        try persistDevices()
        await auditLogger.log(.pairingCompleted, deviceId: device.id)
    }

    public func removeTrustedDevice(_ deviceId: UUID) async throws {
        trustedDevices.removeValue(forKey: deviceId)
        try persistDevices()
        await auditLogger.log(.deviceRevoked, deviceId: deviceId)
    }

    public func isTrusted(_ deviceId: UUID) -> Bool {
        trustedDevices[deviceId] != nil
    }

    public func publicKey(for deviceId: UUID) -> Data? {
        trustedDevices[deviceId]?.publicKeyData
    }

    public func device(for id: UUID) -> DeviceIdentity? {
        trustedDevices[id]
    }

    public func allTrustedDevices() -> [DeviceIdentity] {
        Array(trustedDevices.values)
    }

    private func persistDevices() throws {
        let data = try JSONEncoder().encode(Array(trustedDevices.values))
        try keychainStore.save(data: data, for: Self.storageKey)
    }
}
