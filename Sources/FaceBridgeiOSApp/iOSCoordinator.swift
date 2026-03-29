import Foundation
import SwiftUI
import os
import FaceBridgeCore
import FaceBridgeCrypto
import FaceBridgeProtocol
import FaceBridgeTransport

@MainActor
public final class iOSCoordinator: ObservableObject, @unchecked Sendable {
    @Published public var discoveredDevices: [DiscoveredDevice] = []
    @Published public var trustedDevices: [DeviceIdentity] = []
    @Published public var pairingState: PairingPhase = .idle
    @Published public var pendingAuthRequest: AuthorizationRequest?
    @Published public var pendingAuthDeviceId: UUID?
    @Published public var lastAuthResult: String = ""
    @Published public var logMessages: [LogEntry] = []

    public enum PairingPhase: String {
        case idle, enteringCode, sendingAcceptance, completed, failed
    }

    public struct LogEntry: Identifiable {
        public let id = UUID()
        public let timestamp = Date()
        public let category: String
        public let message: String
    }

    private let localDeviceId = UUID()
    private let keyTag = "com.facebridge.ios.device-key"

    private let lanTransport: LocalNetworkTransport
    private let bleTransport: BLETransport
    private let connectionManager = ConnectionManager()
    private let trustManager: DeviceTrustManager
    private let keyManager: SoftwareKeyManager
    private let responder: AuthorizationResponder
    private let auditLogger = AuditLogger()
    private let encoder = MessageEncoder()
    private var transportBridge: iOSTransportBridge?

    public var localPublicKeyData: Data?
    private var deviceTransportMap: [UUID: any Transport] = [:]

    public init() {
        let store = KeychainStore()
        let km = SoftwareKeyManager(store: store)
        self.keyManager = km
        let tm = DeviceTrustManager(keychainStore: store, auditLogger: AuditLogger())
        self.trustManager = tm
        self.responder = AuthorizationResponder(
            localDeviceId: UUID(),
            keyManager: km,
            trustManager: tm
        )
        self.lanTransport = LocalNetworkTransport(allowInsecure: true)
        self.bleTransport = BLETransport()
    }

    public func start() {
        log("lifecycle", "iOS coordinator starting")
        do {
            localPublicKeyData = try keyManager.generateKeyPair(tag: keyTag)
            log("crypto", "Device key pair generated")
        } catch {
            log("crypto", "Key generation: using existing key")
            localPublicKeyData = try? keyManager.publicKeyData(for: keyTag)
        }

        let bridge = iOSTransportBridge(coordinator: self)
        self.transportBridge = bridge
        lanTransport.delegate = bridge
        bleTransport.delegate = bridge

        Task {
            await connectionManager.register(lanTransport)
            await connectionManager.register(bleTransport)
        }

        lanTransport.startDiscovery()
        log("transport", "LAN discovery started")

        do {
            try lanTransport.startListening()
            log("transport", "LAN listener started")
        } catch {
            log("transport", "LAN listener failed: \(error)")
        }

        bleTransport.startDiscovery()
        log("transport", "BLE discovery started")

        bleTransport.startAdvertising(displayName: "FaceBridge-iPhone")
        log("transport", "BLE advertising started")

        Task {
            try? await trustManager.loadTrustedDevices()
            let devices = await trustManager.allTrustedDevices()
            await MainActor.run { self.trustedDevices = devices }
            log("lifecycle", "Loaded \(devices.count) trusted device(s)")
        }

        log("lifecycle", "iOS coordinator ready — local device ID: \(localDeviceId)")
    }

    public func submitPairingCode(_ code: String, toDeviceId deviceId: UUID) {
        pairingState = .sendingAcceptance
        Task {
            do {
                guard let pubKey = localPublicKeyData else {
                    throw FaceBridgeError.keyGenerationFailed
                }

                log("pairing", "Connecting to device \(deviceId)…")
                try await ensureConnected(to: deviceId)

                let signable = Data(localDeviceId.uuidString.utf8)
                    + Data("FaceBridge-iPhone".utf8)
                    + Data(DevicePlatform.iOS.rawValue.utf8)
                    + pubKey
                    + Data(deviceId.uuidString.utf8)
                let signature = try keyManager.sign(data: signable, keyTag: keyTag)

                let acceptance = PairingAcceptance(
                    deviceId: localDeviceId,
                    displayName: "FaceBridge-iPhone",
                    platform: .iOS,
                    publicKeyData: pubKey,
                    invitationDeviceId: deviceId,
                    signature: signature
                )

                let envelope = try encoder.encode(acceptance, type: .pairingAcceptance, sequenceNumber: 1)
                try await sendToDevice(envelope, deviceId: deviceId)

                await MainActor.run { self.pairingState = .completed }
                log("pairing", "Acceptance sent to \(deviceId)")
            } catch {
                await MainActor.run { self.pairingState = .failed }
                log("pairing", "Failed to send acceptance: \(error)")
            }
        }
    }

    private func ensureConnected(to deviceId: UUID) async throws {
        if deviceTransportMap[deviceId] != nil { return }
        try await lanTransport.connect(to: deviceId)
        deviceTransportMap[deviceId] = lanTransport
        log("transport", "Outgoing connection established to \(deviceId)")
    }

    private func sendToDevice(_ envelope: MessageEnvelope, deviceId: UUID) async throws {
        if let transport = deviceTransportMap[deviceId] {
            try await transport.send(envelope, to: deviceId)
        } else {
            try await lanTransport.send(envelope, to: deviceId)
        }
    }

    public func approveAuth() {
        guard let request = pendingAuthRequest, let deviceId = pendingAuthDeviceId else { return }
        Task {
            do {
                try await ensureConnected(to: deviceId)
                let response = try await responder.respond(to: request, keyTag: keyTag)
                let envelope = try encoder.encode(response, type: .authorizationResponse, sequenceNumber: 1)
                try await sendToDevice(envelope, deviceId: deviceId)

                await MainActor.run {
                    self.lastAuthResult = "Response sent: \(response.decision.rawValue)"
                    self.pendingAuthRequest = nil
                    self.pendingAuthDeviceId = nil
                }
                log("authorization", "Response sent: \(response.decision.rawValue)")
            } catch {
                log("authorization", "Failed to respond: \(error)")
                await MainActor.run {
                    self.lastAuthResult = "Error: \(error.localizedDescription)"
                    self.pendingAuthRequest = nil
                }
            }
        }
    }

    public func denyAuth() {
        pendingAuthRequest = nil
        pendingAuthDeviceId = nil
        lastAuthResult = "Denied by user"
        log("authorization", "Denied by user (no biometric)")
    }

    func handleDiscovery(_ device: DiscoveredDevice) {
        Task { @MainActor in
            if !discoveredDevices.contains(where: { $0.id == device.id }) {
                discoveredDevices.append(device)
            }
        }
        log("transport", "Discovered: \(device.displayName) via \(device.transportType.rawValue)")
    }

    func handleConnect(_ deviceId: UUID, transport: (any Transport)?) {
        log("transport", "Connected: \(deviceId)")
        if let transport {
            deviceTransportMap[deviceId] = transport
        }
        bleTransport.authorizePeer(deviceId)
    }

    func handleDisconnect(_ deviceId: UUID) {
        log("transport", "Disconnected: \(deviceId)")
        deviceTransportMap.removeValue(forKey: deviceId)
    }

    func handleReceive(_ envelope: MessageEnvelope, from deviceId: UUID, transport: (any Transport)?) {
        log("transport", "Received envelope type=\(envelope.type.rawValue) from \(deviceId)")
        if let transport, deviceTransportMap[deviceId] == nil {
            deviceTransportMap[deviceId] = transport
        }

        switch envelope.type {
        case .authorizationRequest:
            handleIncomingAuthRequest(envelope, from: deviceId)
        case .pairingInvitation:
            log("pairing", "Received pairing invitation from \(deviceId)")
        default:
            log("transport", "Unhandled envelope type: \(envelope.type.rawValue)")
        }
    }

    func handleError(_ error: FaceBridgeError) {
        log("transport", "Transport error: \(error.localizedDescription)")
    }

    private func handleIncomingAuthRequest(_ envelope: MessageEnvelope, from deviceId: UUID) {
        Task {
            do {
                let request = try JSONDecoder().decode(AuthorizationRequest.self, from: envelope.payload)
                log("authorization", "Auth request from \(request.senderDeviceId): \(request.reason)")
                await MainActor.run {
                    self.pendingAuthRequest = request
                    self.pendingAuthDeviceId = deviceId
                }
            } catch {
                log("authorization", "Failed to decode auth request: \(error)")
            }
        }
    }

    func log(_ category: String, _ message: String) {
        let entry = LogEntry(category: category, message: message)
        DebugLogger.lifecycle.info("[\(category)] \(message)")
        Task { @MainActor in
            self.logMessages.append(entry)
            if self.logMessages.count > 200 {
                self.logMessages.removeFirst(50)
            }
        }
    }
}

final class iOSTransportBridge: TransportDelegate, @unchecked Sendable {
    private weak var coordinator: iOSCoordinator?

    init(coordinator: iOSCoordinator) {
        self.coordinator = coordinator
    }

    func transport(_ transport: any Transport, didDiscover device: DiscoveredDevice) {
        Task { @MainActor in coordinator?.handleDiscovery(device) }
    }

    func transport(_ transport: any Transport, didConnect deviceId: UUID) {
        Task { @MainActor in coordinator?.handleConnect(deviceId, transport: transport) }
    }

    func transport(_ transport: any Transport, didDisconnect deviceId: UUID) {
        Task { @MainActor in coordinator?.handleDisconnect(deviceId) }
    }

    func transport(_ transport: any Transport, didReceive envelope: MessageEnvelope, from deviceId: UUID) {
        Task { @MainActor in coordinator?.handleReceive(envelope, from: deviceId, transport: transport) }
    }

    func transport(_ transport: any Transport, didFailWithError error: FaceBridgeError) {
        Task { @MainActor in coordinator?.handleError(error) }
    }
}
