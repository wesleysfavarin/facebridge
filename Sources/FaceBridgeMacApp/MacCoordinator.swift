import Foundation
import SwiftUI
import os
import FaceBridgeCore
import FaceBridgeCrypto
import FaceBridgeProtocol
import FaceBridgeTransport

@MainActor
public final class MacCoordinator: ObservableObject, @unchecked Sendable {

    // MARK: - Published State

    @Published public var discoveredDevices: [DiscoveredDevice] = []
    @Published public var pairedDevices: [DeviceIdentity] = []
    @Published public var mergedNearbyDevices: [NearbyDevice] = []

    @Published public var connectionStatus: ConnectionStatus = .searching
    @Published public var pairingCode: String = ""
    @Published public var pairingState: PairingPhase = .idle
    @Published public var lastAuthResult: String = ""
    @Published public var lastAuthTimestamp: Date?
    @Published public var logMessages: [LogEntry] = []

    @Published public var authPhase: AuthorizationPhase = .idle
    @Published public var isVaultUnlocked: Bool = false
    @Published public var vaultUnlockedAt: Date?

    @Published public var developerModeEnabled: Bool {
        didSet { UserDefaults.standard.set(developerModeEnabled, forKey: "fb_mac_developer_mode") }
    }

    // MARK: - Types

    public enum ConnectionStatus: String {
        case searching = "Searching…"
        case deviceNearby = "Device nearby"
        case paired = "Paired"
        case connectedSecurely = "Connected securely"
    }

    public enum PairingPhase: String {
        case idle, generatingCode, waitingForAcceptance, verifyingSAS, completed, failed
    }

    public enum AuthorizationPhase: String {
        case idle
        case sending = "Sending request…"
        case waitingForApproval = "Waiting for iPhone…"
        case approved = "Approved"
        case denied = "Denied"
        case expired = "Expired"
        case failed = "Failed"
    }

    public struct NearbyDevice: Identifiable, Hashable {
        public let id: UUID
        public let friendlyName: String
        public let platform: DevicePlatform?
        public let isTrusted: Bool
        public let transportIds: Set<UUID>
        public var isConnected: Bool

        public static func == (lhs: NearbyDevice, rhs: NearbyDevice) -> Bool { lhs.id == rhs.id }
        public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    public struct LogEntry: Identifiable {
        public let id = UUID()
        public let timestamp = Date()
        public let category: String
        public let message: String
    }

    // MARK: - Private

    private let localDeviceId: UUID
    private let keyTag = "com.facebridge.mac.device-key"

    private let lanTransport: LocalNetworkTransport
    private let bleTransport: BLETransport
    private let connectionManager = ConnectionManager()
    private let pairingController = PairingFlowController()
    private let deviceManager: PairedDeviceManager
    private let keyManager: SoftwareKeyManager
    private let requester: AuthorizationRequester
    private let auditLogger = AuditLogger()
    private let encoder = MessageEncoder()
    private var transportBridge: MacTransportBridge?

    public var localPublicKeyData: Data?
    private var pendingRequests: [UUID: AuthorizationRequest] = [:]
    private var deviceTransportMap: [UUID: any Transport] = [:]

    // MARK: - Init

    public init() {
        self.localDeviceId = Self.loadOrCreateDeviceId(key: "fb_mac_device_id")
        let store = KeychainStore()
        self.keyManager = SoftwareKeyManager(store: store)
        self.deviceManager = PairedDeviceManager(keychainStore: store, auditLogger: AuditLogger())
        self.requester = AuthorizationRequester(keyManager: keyManager, auditLogger: auditLogger)
        self.lanTransport = LocalNetworkTransport(allowInsecure: true)
        self.bleTransport = BLETransport()
        self.developerModeEnabled = UserDefaults.standard.bool(forKey: "fb_mac_developer_mode")
    }

    private static func loadOrCreateDeviceId(key: String) -> UUID {
        if let string = UserDefaults.standard.string(forKey: key),
           let id = UUID(uuidString: string) {
            return id
        }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: key)
        return id
    }

    // MARK: - Lifecycle

    public func start() {
        log("lifecycle", "Mac coordinator starting (deviceId=\(localDeviceId.uuidString.prefix(8)))")

        if let existingKey = try? keyManager.publicKeyData(for: keyTag) {
            localPublicKeyData = existingKey
            log("crypto", "Loaded existing device key (\(existingKey.count) bytes)")
        } else {
            do {
                localPublicKeyData = try keyManager.generateKeyPair(tag: keyTag)
                log("crypto", "Generated new device key pair")
            } catch {
                log("crypto", "Key generation failed: \(error)")
            }
        }

        let bridge = MacTransportBridge(coordinator: self)
        self.transportBridge = bridge
        lanTransport.delegate = bridge
        bleTransport.delegate = bridge

        Task { await connectionManager.register(lanTransport) }
        Task { await connectionManager.register(bleTransport) }

        do { try lanTransport.startListening() } catch { log("transport", "LAN listener failed: \(error)") }
        lanTransport.startDiscovery()
        bleTransport.startDiscovery()
        bleTransport.startAdvertising(displayName: hostName())

        Task {
            try? await deviceManager.loadPairedDevices()
            let devices = await deviceManager.allPairedDevices()
            await MainActor.run {
                self.pairedDevices = devices
                if !devices.isEmpty { self.connectionStatus = .paired }
            }
            log("lifecycle", "Loaded \(devices.count) paired device(s)")
        }

        log("lifecycle", "Mac coordinator ready")
    }

    // MARK: - Pairing

    public func generatePairingCode() {
        pairingState = .generatingCode
        Task {
            do {
                let code = try await pairingController.generateInvitationCode()
                await MainActor.run {
                    self.pairingCode = code
                    self.pairingState = .waitingForAcceptance
                }
                log("pairing", "Code generated: \(code)")
            } catch {
                await MainActor.run { self.pairingState = .failed }
                log("pairing", "Code generation failed: \(error)")
            }
        }
    }

    // MARK: - Authorization

    public func requestAuthorization(reason: String) {
        guard let device = mergedNearbyDevices.first(where: { $0.isTrusted }),
              let transportId = device.transportIds.first else {
            if pairedDevices.isEmpty {
                log("authorization", "No paired devices — pair your iPhone first")
                lastAuthResult = "No paired device"
            } else {
                log("authorization", "Paired device not nearby")
                lastAuthResult = "Device not nearby"
            }
            authPhase = .failed
            return
        }
        sendAuthorizationRequest(to: transportId, reason: reason)
    }

    public func requestVaultUnlock() {
        isVaultUnlocked = false
        requestAuthorization(reason: "Unlock Secure Vault on your Mac")
    }

    public func lockVault() {
        isVaultUnlocked = false
        vaultUnlockedAt = nil
        log("vault", "Vault locked")
    }

    public func sendAuthorizationRequest(to deviceId: UUID, reason: String) {
        authPhase = .sending
        Task {
            do {
                log("authorization", "[auth_req] Creating request (reason: \(reason))")
                try await ensureConnected(to: deviceId)
                let request = try await requester.createRequest(
                    senderDeviceId: localDeviceId, keyTag: keyTag,
                    reason: reason, transportType: "lan", ttl: 30
                )
                let envelope = try encoder.encode(request, type: .authorizationRequest, sequenceNumber: 1)
                try await sendToDevice(envelope, deviceId: deviceId)
                pendingRequests[request.id] = request
                log("authorization", "[auth_req] Request sent (id=\(request.id.uuidString.prefix(8)))")
                await MainActor.run {
                    self.authPhase = .waitingForApproval
                    self.lastAuthResult = "Waiting for iPhone…"
                }
            } catch {
                log("authorization", "[auth_req] Send failed: \(error)")
                await MainActor.run {
                    self.authPhase = .failed
                    self.lastAuthResult = "Send failed"
                }
            }
        }
    }

    public func sendAuthToFirstPairedDevice(reason: String) {
        requestAuthorization(reason: reason)
    }

    // MARK: - Device Deduplication

    public func rebuildMergedDevices() {
        var merged: [String: NearbyDevice] = [:]

        for device in discoveredDevices {
            let key = friendlyName(for: device.displayName)
            if var existing = merged[key] {
                var ids = existing.transportIds
                ids.insert(device.id)
                existing = NearbyDevice(
                    id: existing.id, friendlyName: existing.friendlyName,
                    platform: existing.platform, isTrusted: existing.isTrusted,
                    transportIds: ids, isConnected: existing.isConnected || deviceTransportMap[device.id] != nil
                )
                merged[key] = existing
            } else {
                let isTrusted = pairedDevices.contains { friendlyName(for: $0.displayName) == key }
                merged[key] = NearbyDevice(
                    id: device.id, friendlyName: key,
                    platform: isTrusted ? pairedDevices.first(where: { friendlyName(for: $0.displayName) == key })?.platform : nil,
                    isTrusted: isTrusted, transportIds: [device.id],
                    isConnected: deviceTransportMap[device.id] != nil
                )
            }
        }

        mergedNearbyDevices = Array(merged.values).sorted { ($0.isTrusted ? 0 : 1) < ($1.isTrusted ? 0 : 1) }
        updateConnectionStatus()
    }

    public func friendlyNamePublic(for rawName: String) -> String {
        friendlyName(for: rawName)
    }

    private func friendlyName(for rawName: String) -> String {
        var name = rawName
        name = name.replacingOccurrences(of: "\\032", with: " ")
        if let range = name.range(of: "._facebridge._tcp.local.") { name = String(name[..<range.lowerBound]) }
        if let range = name.range(of: "._tcp.local.") { name = String(name[..<range.lowerBound]) }
        if let range = name.range(of: ".local.") { name = String(name[..<range.lowerBound]) }
        name = name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Unknown Device" : name
    }

    private func updateConnectionStatus() {
        if mergedNearbyDevices.contains(where: { $0.isTrusted && $0.isConnected }) {
            connectionStatus = .connectedSecurely
        } else if !pairedDevices.isEmpty {
            connectionStatus = .paired
        } else if !mergedNearbyDevices.isEmpty {
            connectionStatus = .deviceNearby
        } else {
            connectionStatus = .searching
        }
    }

    func hostName() -> String {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return "Mac"
        #endif
    }

    // MARK: - Transport Helpers

    private func ensureConnected(to deviceId: UUID) async throws {
        if deviceTransportMap[deviceId] != nil { return }
        try await lanTransport.connect(to: deviceId)
        deviceTransportMap[deviceId] = lanTransport
    }

    private func sendToDevice(_ envelope: MessageEnvelope, deviceId: UUID) async throws {
        if let transport = deviceTransportMap[deviceId] {
            try await transport.send(envelope, to: deviceId)
        } else {
            try await lanTransport.send(envelope, to: deviceId)
        }
    }

    // MARK: - Transport Delegate

    func handleDiscovery(_ device: DiscoveredDevice) {
        let localName = hostName().lowercased()
        let deviceFriendly = friendlyName(for: device.displayName).lowercased()
        if deviceFriendly == localName || device.displayName.lowercased().contains(localName.replacingOccurrences(of: " ", with: "\\032")) {
            return
        }
        Task { @MainActor in
            if !discoveredDevices.contains(where: { $0.id == device.id }) {
                discoveredDevices.append(device)
                rebuildMergedDevices()
            }
        }
        log("transport", "Discovered: \(device.displayName)")
    }

    func handleConnect(_ deviceId: UUID, transport: (any Transport)?) {
        if let transport { deviceTransportMap[deviceId] = transport }
        rebuildMergedDevices()
        log("transport", "Connected: \(deviceId.uuidString.prefix(8))")
    }

    func handleDisconnect(_ deviceId: UUID) {
        deviceTransportMap.removeValue(forKey: deviceId)
        rebuildMergedDevices()
        log("transport", "Disconnected: \(deviceId.uuidString.prefix(8))")
    }

    func handleReceive(_ envelope: MessageEnvelope, from deviceId: UUID, transport: (any Transport)?) {
        log("transport", "[recv] type=\(envelope.type.rawValue) from=\(deviceId.uuidString.prefix(8))")
        if let transport, deviceTransportMap[deviceId] == nil {
            deviceTransportMap[deviceId] = transport
        }
        switch envelope.type {
        case .pairingAcceptance:
            handlePairingAcceptance(envelope, from: deviceId)
        case .authorizationResponse:
            handleAuthorizationResponse(envelope, from: deviceId)
        default:
            log("transport", "Unhandled: \(envelope.type.rawValue)")
        }
    }

    func handleError(_ error: FaceBridgeError) {
        log("transport", "Error: \(error.localizedDescription)")
    }

    private func handlePairingAcceptance(_ envelope: MessageEnvelope, from deviceId: UUID) {
        Task {
            do {
                log("pairing", "[stage_1] Decoding PairingAcceptance…")
                let acceptance = try encoder.decode(PairingAcceptance.self, from: envelope)
                log("pairing", "[stage_1] Peer: \(acceptance.displayName) (\(acceptance.platform.rawValue))")

                let peerIdentity = try DeviceIdentity(
                    id: acceptance.deviceId, displayName: acceptance.displayName,
                    platform: acceptance.platform, publicKeyData: acceptance.publicKeyData
                )
                log("pairing", "[stage_2] Peer identity valid — storing trust")

                try await deviceManager.addPairedDevice(peerIdentity)
                log("pairing", "[stage_3] Peer stored in PairedDeviceManager")

                guard let myPubKey = localPublicKeyData else {
                    log("pairing", "[ERROR] Local public key unavailable")
                    await MainActor.run { self.pairingState = .failed }
                    return
                }

                let signable = Data(localDeviceId.uuidString.utf8)
                    + Data(acceptance.deviceId.uuidString.utf8)
                    + Data("true".utf8)
                let signature = try keyManager.sign(data: signable, keyTag: keyTag)

                let confirmation = PairingConfirmation(
                    deviceId: localDeviceId,
                    peerDeviceId: acceptance.deviceId,
                    confirmed: true,
                    sas: "",
                    signature: signature,
                    displayName: hostName(),
                    platform: .macOS,
                    publicKeyData: myPubKey
                )
                let confirmEnvelope = try encoder.encode(confirmation, type: .pairingConfirmation, sequenceNumber: 2)
                try await sendToDevice(confirmEnvelope, deviceId: deviceId)
                log("pairing", "[stage_4] PairingConfirmation sent")

                let devices = await deviceManager.allPairedDevices()
                await MainActor.run {
                    self.pairedDevices = devices
                    self.pairingState = .completed
                    self.connectionStatus = .paired
                }
                rebuildMergedDevices()
                log("pairing", "[stage_5] Pairing COMPLETE with \(acceptance.displayName)")
            } catch {
                log("pairing", "[ERROR] \(error)")
                await MainActor.run { self.pairingState = .failed }
            }
        }
    }

    private func handleAuthorizationResponse(_ envelope: MessageEnvelope, from deviceId: UUID) {
        Task {
            do {
                log("authorization", "[auth_resp] Decoding response…")
                let response = try encoder.decode(AuthorizationResponse.self, from: envelope)
                log("authorization", "[auth_resp] decision=\(response.decision.rawValue) requestId=\(response.requestId.uuidString.prefix(8))")

                guard let originalRequest = pendingRequests.removeValue(forKey: response.requestId) else {
                    log("authorization", "[auth_resp] No pending request for this ID")
                    await MainActor.run { self.authPhase = .failed; self.lastAuthResult = "Unknown request" }
                    return
                }

                let pubKey = await deviceManager.publicKey(for: response.responderDeviceId)
                guard let trustedKey = pubKey else {
                    log("authorization", "[auth_resp] Responder \(response.responderDeviceId.uuidString.prefix(8)) not in paired devices")
                    await MainActor.run { self.authPhase = .failed; self.lastAuthResult = "Unknown responder" }
                    return
                }

                log("authorization", "[auth_resp] Verifying signature…")
                let valid = try await requester.verify(
                    response: response, originalRequest: originalRequest, trustedPublicKey: trustedKey
                )

                let resultText: String
                let phase: AuthorizationPhase
                if valid {
                    resultText = "Approved"
                    phase = .approved
                    log("authorization", "[auth_resp] APPROVED — signature valid, decision=approved")
                } else if response.decision == .denied {
                    resultText = "Denied"
                    phase = .denied
                    log("authorization", "[auth_resp] DENIED by user")
                } else if response.decision == .expired {
                    resultText = "Expired"
                    phase = .expired
                    log("authorization", "[auth_resp] Request EXPIRED")
                } else {
                    resultText = "Invalid"
                    phase = .failed
                    log("authorization", "[auth_resp] Invalid response")
                }

                let shouldUnlockVault = valid && originalRequest.reason.contains("Vault")

                await MainActor.run {
                    self.authPhase = phase
                    self.lastAuthResult = resultText
                    self.lastAuthTimestamp = Date()
                    if shouldUnlockVault {
                        self.isVaultUnlocked = true
                        self.vaultUnlockedAt = Date()
                    }
                }

                if shouldUnlockVault {
                    log("vault", "Secure Vault UNLOCKED via Face ID authorization")
                }
            } catch {
                log("authorization", "[auth_resp] Verification failed: \(error)")
                await MainActor.run { self.authPhase = .failed; self.lastAuthResult = "Verification failed" }
            }
        }
    }

    // MARK: - Logging

    func log(_ category: String, _ message: String) {
        let entry = LogEntry(category: category, message: message)
        DebugLogger.lifecycle.info("[\(category)] \(message)")
        Task { @MainActor in
            self.logMessages.append(entry)
            if self.logMessages.count > 200 { self.logMessages.removeFirst(50) }
        }
    }
}

// MARK: - Transport Bridge

final class MacTransportBridge: TransportDelegate, @unchecked Sendable {
    private weak var coordinator: MacCoordinator?
    init(coordinator: MacCoordinator) { self.coordinator = coordinator }

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
