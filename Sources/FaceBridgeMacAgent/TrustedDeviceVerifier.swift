import Foundation
import FaceBridgeCore
import FaceBridgeCrypto

public actor TrustedDeviceVerifier {
    private let keychainStore: SecureStorage

    private static let storageKey = "com.facebridge.agent.trusted-devices"

    public init(keychainStore: SecureStorage = KeychainStore()) {
        self.keychainStore = keychainStore
    }

    public func verify(deviceId: UUID) throws -> Bool {
        guard let data = try keychainStore.load(for: Self.storageKey) else { return false }
        let devices = try JSONDecoder().decode([DeviceIdentity].self, from: data)
        return devices.contains { $0.id == deviceId }
    }

    public func publicKey(for deviceId: UUID) throws -> Data? {
        guard let data = try keychainStore.load(for: Self.storageKey) else { return nil }
        let devices = try JSONDecoder().decode([DeviceIdentity].self, from: data)
        return devices.first { $0.id == deviceId }?.publicKeyData
    }
}
