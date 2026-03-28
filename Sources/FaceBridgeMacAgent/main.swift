import Foundation
import FaceBridgeCore
import FaceBridgeTransport

let auditLogger = AuditLogger()
let connectionManager = ConnectionManager()
let listener = BackgroundListener(connectionManager: connectionManager, auditLogger: auditLogger)

@Sendable func gracefulShutdown(reason: String) async {
    await auditLogger.log(.agentStopped, details: reason)
    await listener.stop()
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

await auditLogger.log(.agentStarted, details: "FaceBridge agent started")
await listener.start()

while true {
    try? await Task.sleep(for: .seconds(1))
    await listener.pruneExpired()
    await listener.recoverIfStuck()
}
