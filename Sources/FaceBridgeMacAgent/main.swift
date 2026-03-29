#if os(macOS)
import Foundation
import os
import FaceBridgeCore
import FaceBridgeProtocol
import FaceBridgeTransport

let logger = Logger(subsystem: "com.facebridge", category: "agent")

let auditLogger = AuditLogger()
let connectionManager = ConnectionManager()
let listener = BackgroundListener(connectionManager: connectionManager, auditLogger: auditLogger)

let lanTransport = LocalNetworkTransport(allowInsecure: true)
let bleTransport = BLETransport()

final class AgentTransportBridge: TransportDelegate, @unchecked Sendable {
    func transport(_ transport: any Transport, didDiscover device: DiscoveredDevice) {
        logger.info("[transport] Discovered: \(device.displayName) via \(device.transportType.rawValue) RSSI=\(device.rssi)")
    }
    func transport(_ transport: any Transport, didConnect deviceId: UUID) {
        logger.info("[transport] Connected: \(deviceId)")
    }
    func transport(_ transport: any Transport, didDisconnect deviceId: UUID) {
        logger.info("[transport] Disconnected: \(deviceId)")
    }
    func transport(_ transport: any Transport, didReceive envelope: MessageEnvelope, from deviceId: UUID) {
        logger.info("[transport] Received: type=\(envelope.type.rawValue) from=\(deviceId)")
        if envelope.type == .authorizationRequest {
            Task {
                do {
                    let request = try JSONDecoder().decode(AuthorizationRequest.self, from: envelope.payload)
                    let result = await listener.enqueue(request)
                    logger.info("[agent] Enqueue result: \(String(describing: result))")
                } catch {
                    logger.error("[agent] Failed to decode request: \(error)")
                }
            }
        }
    }
    func transport(_ transport: any Transport, didFailWithError error: FaceBridgeError) {
        logger.error("[transport] Error: \(error.localizedDescription)")
    }
}

let bridge = AgentTransportBridge()

@Sendable func gracefulShutdown(reason: String) async {
    await auditLogger.log(.agentStopped, details: reason)
    await listener.stop()
    logger.info("[agent] Shutdown: \(reason)")
}

func setupSignalHandlers(listener: BackgroundListener, auditLogger: AuditLogger) {
    let signalSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    signalSource.setEventHandler {
        Task {
            await gracefulShutdown(reason: "SIGTERM received")
            exit(0)
        }
    }
    signalSource.resume()
    signal(SIGTERM, SIG_IGN)

    let intSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    intSource.setEventHandler {
        Task {
            await gracefulShutdown(reason: "SIGINT received")
            exit(0)
        }
    }
    intSource.resume()
    signal(SIGINT, SIG_IGN)
}

setupSignalHandlers(listener: listener, auditLogger: auditLogger)

lanTransport.delegate = bridge
bleTransport.delegate = bridge

Task {
    await connectionManager.register(lanTransport)
    await connectionManager.register(bleTransport)
}

do {
    try lanTransport.startListening()
    logger.info("[agent] LAN listener started (_facebridge._tcp)")
} catch {
    logger.error("[agent] LAN listener failed: \(error)")
}

lanTransport.startDiscovery()
logger.info("[agent] LAN discovery started")

bleTransport.startDiscovery()
logger.info("[agent] BLE discovery started")

bleTransport.startAdvertising(displayName: "FaceBridge-Agent")
logger.info("[agent] BLE advertising started")

await auditLogger.log(.agentStarted, details: "FaceBridge agent started with transports")
logger.info("[agent] FaceBridge agent started — listening for connections")

while true {
    try? await Task.sleep(for: .seconds(1))
    await listener.pruneExpired()
    await listener.recoverIfStuck()
    lanTransport.pruneIdleConnections()
}
#else
import Foundation
// Agent is macOS-only; this stub satisfies SPM compilation on iOS.
#endif
