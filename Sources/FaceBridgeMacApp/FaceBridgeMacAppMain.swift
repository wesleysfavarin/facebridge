#if os(macOS)
import SwiftUI
import FaceBridgeCore

@main
struct FaceBridgeMacAppMain: App {
    @StateObject private var coordinator = MacCoordinator()

    var body: some Scene {
        WindowGroup {
            MacMainView()
                .environmentObject(coordinator)
                .onAppear { coordinator.start() }
                .frame(minWidth: 700, minHeight: 500)
        }

        MenuBarExtra {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(menuBarStatusColor)
                        .frame(width: 8, height: 8)
                    Text(coordinator.connectionStatus.rawValue)
                        .font(.headline)
                }
                Divider()

                if coordinator.isVaultUnlocked {
                    HStack {
                        Image(systemName: "lock.open.fill")
                            .foregroundStyle(.green)
                        Text("Vault Unlocked")
                            .foregroundStyle(.green)
                    }
                    Button("Lock Vault") {
                        coordinator.lockVault()
                    }
                    Divider()
                }

                if !coordinator.pairedDevices.isEmpty {
                    Text("Trusted Devices")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(coordinator.pairedDevices, id: \.id) { device in
                        HStack {
                            Image(systemName: device.platform == .iOS ? "iphone" : "laptopcomputer")
                            Text(device.displayName)
                        }
                    }
                    Divider()

                    Text("Protected Actions")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Unlock Secure Vault") {
                        coordinator.requestVaultUnlock()
                    }
                    Button("Run Protected Command") {
                        coordinator.requestDemoCommand()
                    }
                    Button("Reveal Protected File") {
                        coordinator.requestFileReveal()
                    }

                    if coordinator.authPhase == .waitingForApproval {
                        HStack {
                            ProgressView().controlSize(.mini)
                            Text("Waiting for iPhone…")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }

                if !coordinator.lastAuthResult.isEmpty {
                    Divider()
                    HStack {
                        Image(systemName: coordinator.lastAuthResult == "Approved" ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(coordinator.lastAuthResult == "Approved" ? .green : .red)
                        Text("Last: \(coordinator.lastAuthResult)")
                            .font(.caption)
                    }
                }

                Divider()
                Button("Quit FaceBridge") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(8)
        } label: {
            Image(systemName: menuBarIcon)
        }
    }

    private var menuBarStatusColor: Color {
        switch coordinator.connectionStatus {
        case .searching: return .orange
        case .deviceNearby: return .blue
        case .paired, .connectedSecurely: return .green
        }
    }

    private var menuBarIcon: String {
        if coordinator.isVaultUnlocked { return "lock.open.fill" }
        switch coordinator.connectionStatus {
        case .searching: return "faceid"
        case .deviceNearby: return "faceid"
        case .paired: return "faceid"
        case .connectedSecurely: return "lock.shield.fill"
        }
    }
}
#else
import SwiftUI

@main
struct FaceBridgeMacAppMain: App {
    var body: some Scene {
        WindowGroup { Text("FaceBridgeMacApp requires macOS") }
    }
}
#endif
