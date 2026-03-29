import Foundation
import FaceBridgeCore

public struct PairingInvitation: Codable, Sendable {
    public let deviceId: UUID
    public let displayName: String
    public let platform: DevicePlatform
    public let publicKeyData: Data
    public let pairingCode: String
    public let signature: Data
    public let createdAt: Date

    public init(
        deviceId: UUID,
        displayName: String,
        platform: DevicePlatform,
        publicKeyData: Data,
        pairingCode: String,
        signature: Data,
        createdAt: Date = Date()
    ) {
        self.deviceId = deviceId
        self.displayName = displayName
        self.platform = platform
        self.publicKeyData = publicKeyData
        self.pairingCode = pairingCode
        self.signature = signature
        self.createdAt = createdAt
    }

    public var signable: Data {
        var payload = Data()
        payload.append(Data(deviceId.uuidString.utf8))
        payload.append(Data(displayName.utf8))
        payload.append(Data(platform.rawValue.utf8))
        payload.append(publicKeyData)
        payload.append(Data(pairingCode.utf8))
        return payload
    }
}

public struct PairingAcceptance: Codable, Sendable {
    public let deviceId: UUID
    public let displayName: String
    public let platform: DevicePlatform
    public let publicKeyData: Data
    public let invitationDeviceId: UUID
    public let signature: Data
    public let createdAt: Date

    public init(
        deviceId: UUID,
        displayName: String,
        platform: DevicePlatform,
        publicKeyData: Data,
        invitationDeviceId: UUID,
        signature: Data,
        createdAt: Date = Date()
    ) {
        self.deviceId = deviceId
        self.displayName = displayName
        self.platform = platform
        self.publicKeyData = publicKeyData
        self.invitationDeviceId = invitationDeviceId
        self.signature = signature
        self.createdAt = createdAt
    }

    public var signable: Data {
        var payload = Data()
        payload.append(Data(deviceId.uuidString.utf8))
        payload.append(Data(displayName.utf8))
        payload.append(Data(platform.rawValue.utf8))
        payload.append(publicKeyData)
        payload.append(Data(invitationDeviceId.uuidString.utf8))
        return payload
    }
}

public struct PairingConfirmation: Codable, Sendable {
    public let deviceId: UUID
    public let peerDeviceId: UUID
    public let confirmed: Bool
    public let sas: String
    public let signature: Data
    public let displayName: String
    public let platform: DevicePlatform
    public let publicKeyData: Data
    public let createdAt: Date

    public init(
        deviceId: UUID,
        peerDeviceId: UUID,
        confirmed: Bool,
        sas: String,
        signature: Data,
        displayName: String,
        platform: DevicePlatform,
        publicKeyData: Data,
        createdAt: Date = Date()
    ) {
        self.deviceId = deviceId
        self.peerDeviceId = peerDeviceId
        self.confirmed = confirmed
        self.sas = sas
        self.signature = signature
        self.displayName = displayName
        self.platform = platform
        self.publicKeyData = publicKeyData
        self.createdAt = createdAt
    }

    public var signable: Data {
        var payload = Data()
        payload.append(Data(deviceId.uuidString.utf8))
        payload.append(Data(peerDeviceId.uuidString.utf8))
        payload.append(Data((confirmed ? "true" : "false").utf8))
        payload.append(Data(sas.utf8))
        return payload
    }
}
