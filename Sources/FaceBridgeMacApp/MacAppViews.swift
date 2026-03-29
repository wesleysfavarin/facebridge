#if os(macOS)
import SwiftUI
import FaceBridgeCore
import FaceBridgeSharedUI
import FaceBridgeTransport

// MARK: - Root View

public struct MacMainView: View {
    @EnvironmentObject var coordinator: MacCoordinator
    @State private var selectedSection: MacSection? = .dashboard

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(MacSection.allCases(developerMode: coordinator.developerModeEnabled), selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
            }
            .navigationTitle("FaceBridge")
        } detail: {
            switch selectedSection ?? .dashboard {
            case .dashboard:
                MacDashboardView()
            case .vault:
                MacSecureVaultView()
            case .devices:
                MacDevicesView()
            case .pairing:
                MacPairingView()
            case .settings:
                MacSettingsView()
            case .authLab:
                MacAuthLabView()
            case .debug:
                MacDebugView()
            }
        }
    }
}

// MARK: - Sections

enum MacSection: String, Identifiable, Hashable {
    case dashboard, vault, devices, pairing, settings, authLab, debug

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .vault: return "Secure Vault"
        case .devices: return "Trusted Devices"
        case .pairing: return "Pair New Device"
        case .settings: return "Settings"
        case .authLab: return "Authorization Lab"
        case .debug: return "Debug Console"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .vault: return "lock.shield"
        case .devices: return "iphone.and.arrow.forward"
        case .pairing: return "link.badge.plus"
        case .settings: return "gear"
        case .authLab: return "flask"
        case .debug: return "ant"
        }
    }

    static func allCases(developerMode: Bool) -> [MacSection] {
        var sections: [MacSection] = [.dashboard, .vault, .devices, .pairing, .settings]
        if developerMode { sections.append(contentsOf: [.authLab, .debug]) }
        return sections
    }
}

// MARK: - Dashboard

struct MacDashboardView: View {
    @EnvironmentObject var coordinator: MacCoordinator

    private var isWaiting: Bool {
        coordinator.authPhase == .sending || coordinator.authPhase == .waitingForApproval
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MacConnectionStatusCard(status: coordinator.connectionStatus)

                // Protected Actions
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Protected Actions", systemImage: "lock.shield.fill")
                            .font(.headline)

                        ProtectedActionButton(
                            title: "Unlock Secure Vault",
                            icon: "lock.shield",
                            description: coordinator.isVaultUnlocked ? "Vault is unlocked" : "Requires Face ID approval",
                            status: coordinator.isVaultUnlocked ? .unlocked : actionStatus(for: .unlockVault),
                            isWaiting: isWaiting && coordinator.activeAction == .unlockVault
                        ) {
                            coordinator.requestVaultUnlock()
                        }
                        .disabled(coordinator.pairedDevices.isEmpty || isWaiting)

                        ProtectedActionButton(
                            title: "Run Protected Command",
                            icon: "terminal",
                            description: coordinator.demoCommandResult.isEmpty
                                ? "Opens Safari after Face ID approval"
                                : coordinator.demoCommandResult,
                            status: coordinator.demoCommandResult.isEmpty ? actionStatus(for: .demoCommand) : .completed,
                            isWaiting: isWaiting && coordinator.activeAction == .demoCommand
                        ) {
                            coordinator.requestDemoCommand()
                        }
                        .disabled(coordinator.pairedDevices.isEmpty || isWaiting)

                        ProtectedActionButton(
                            title: "Reveal Protected File",
                            icon: "doc.text.magnifyingglass",
                            description: coordinator.isFileRevealed
                                ? "File content revealed"
                                : "Hidden until Face ID approval",
                            status: coordinator.isFileRevealed ? .unlocked : actionStatus(for: .revealFile),
                            isWaiting: isWaiting && coordinator.activeAction == .revealFile
                        ) {
                            coordinator.requestFileReveal()
                        }
                        .disabled(coordinator.pairedDevices.isEmpty || isWaiting)

                        if coordinator.pairedDevices.isEmpty {
                            Label("Pair your iPhone first to use protected actions", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(4)
                }

                if coordinator.authPhase != .idle {
                    MacAuthStatusCard(phase: coordinator.authPhase, result: coordinator.lastAuthResult)
                }

                if coordinator.isVaultUnlocked, let unlockedAt = coordinator.vaultUnlockedAt {
                    GroupBox {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.open.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Secure Vault Unlocked")
                                    .font(.headline)
                                    .foregroundStyle(.green)
                                Text("Unlocked \(unlockedAt, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Lock") { coordinator.lockVault() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                        .padding(4)
                    }
                }

                if coordinator.isFileRevealed {
                    GroupBox {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                            Text("Protected File Revealed")
                                .font(.headline)
                                .foregroundStyle(.green)
                            Spacer()
                            Button("Hide") { coordinator.hideProtectedFile() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                        .padding(4)
                    }
                }

                if !coordinator.pairedDevices.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Trusted Devices", systemImage: "checkmark.shield")
                                    .font(.headline)
                                Spacer()
                                Text("\(coordinator.pairedDevices.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                            }

                            ForEach(coordinator.pairedDevices, id: \.id) { device in
                                HStack(spacing: 12) {
                                    Image(systemName: device.platform == .iOS ? "iphone" : "laptopcomputer")
                                        .font(.title3)
                                        .foregroundStyle(.blue)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.displayName)
                                            .fontWeight(.medium)
                                        Text("\(device.platform.rawValue) · \(device.id.uuidString.prefix(8))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if coordinator.mergedNearbyDevices.contains(where: { $0.isConnected }) {
                                        Circle().fill(.green).frame(width: 8, height: 8)
                                    } else {
                                        Circle().fill(.orange).frame(width: 8, height: 8)
                                    }
                                    Button(role: .destructive) {
                                        coordinator.removePairedDevice(device.id)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove this device")
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(4)
                    }
                }

                if let timestamp = coordinator.lastAuthTimestamp {
                    GroupBox {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Last Authorization")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(timestamp, style: .relative)
                                    .font(.body)
                                + Text(" ago")
                            }
                            Spacer()
                            Text(coordinator.lastAuthResult)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(coordinator.lastAuthResult == "Approved" ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                .foregroundStyle(coordinator.lastAuthResult == "Approved" ? .green : .orange)
                                .clipShape(Capsule())
                        }
                        .padding(4)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Dashboard")
    }

    private func actionStatus(for action: MacCoordinator.ProtectedAction) -> ProtectedActionStatus {
        guard coordinator.activeAction == action else { return .locked }
        switch coordinator.authPhase {
        case .approved: return .completed
        case .denied: return .denied
        case .expired: return .expired
        default: return .locked
        }
    }
}

enum ProtectedActionStatus {
    case locked, unlocked, completed, denied, expired
}

struct ProtectedActionButton: View {
    let title: String
    let icon: String
    let description: String
    let status: ProtectedActionStatus
    let isWaiting: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(statusColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                    if isWaiting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: icon)
                            .font(.body)
                            .foregroundStyle(statusColor)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isWaiting ? Color.blue.opacity(0.04) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch status {
        case .locked: return .blue
        case .unlocked, .completed: return .green
        case .denied: return .orange
        case .expired: return .red
        }
    }

    private var statusIcon: String {
        if isWaiting { return "arrow.triangle.2.circlepath" }
        switch status {
        case .locked: return "chevron.right"
        case .unlocked, .completed: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .expired: return "clock.badge.exclamationmark"
        }
    }
}

// MARK: - Auth Status Card

struct MacAuthStatusCard: View {
    let phase: MacCoordinator.AuthorizationPhase
    let result: String

    var body: some View {
        GroupBox {
            HStack(spacing: 12) {
                if phase == .sending || phase == .waitingForApproval {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: statusIcon)
                        .font(.title3)
                        .foregroundStyle(statusColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Authorization")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(phase.rawValue)
                        .font(.headline)
                        .foregroundStyle(statusColor)
                    if !result.isEmpty && result != phase.rawValue {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(4)
        }
    }

    private var statusColor: Color {
        switch phase {
        case .idle: return .secondary
        case .sending, .waitingForApproval: return .blue
        case .approved: return .green
        case .denied: return .orange
        case .expired, .sendFailed, .noTrustedDevice, .transportUnavailable, .peerDisconnected, .verificationFailed:
            return .red
        }
    }

    private var statusIcon: String {
        switch phase {
        case .idle: return "minus.circle"
        case .sending: return "arrow.up.circle"
        case .waitingForApproval: return "iphone"
        case .approved: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .expired: return "clock.badge.exclamationmark"
        case .sendFailed, .transportUnavailable, .peerDisconnected: return "wifi.exclamationmark"
        case .noTrustedDevice: return "iphone.slash"
        case .verificationFailed: return "exclamationmark.shield.fill"
        }
    }
}

// MARK: - Secure Vault (Protected Feature)

struct MacSecureVaultView: View {
    @EnvironmentObject var coordinator: MacCoordinator

    var body: some View {
        VStack(spacing: 0) {
            if coordinator.isVaultUnlocked {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "lock.open.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Secure Vault")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                if let t = coordinator.vaultUnlockedAt {
                                    Text("Unlocked \(t, style: .relative) ago via Face ID")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Lock Vault") { coordinator.lockVault() }
                                .buttonStyle(.bordered)
                                .tint(.red)
                        }

                        Divider()

                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Protected Credentials", systemImage: "key.fill")
                                    .font(.headline)
                                VaultCredentialRow(service: "Production Database", username: "admin@facebridge.io", value: "fb-prod-2026-x9k4m")
                                VaultCredentialRow(service: "API Gateway", username: "service-account", value: "sk_live_Rk8f2nVpQm7xJz3L")
                                VaultCredentialRow(service: "Deployment Key", username: "ci/cd-pipeline", value: "deploy-7f3a9c2b-e1d4-48f6")
                            }
                            .padding(4)
                        }

                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Secure Notes", systemImage: "doc.text.fill")
                                    .font(.headline)
                                Text("Recovery Phrase").fontWeight(.medium)
                                Text("apple banana cherry delta echo foxtrot golf hotel india juliet kilo lima")
                                    .font(.system(.body, design: .monospaced))
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .padding(4)
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.secondary)
                    Text("Secure Vault").font(.title).fontWeight(.bold)
                    Text("This vault contains protected credentials and secure notes. Unlock it by authorizing with Face ID on your paired iPhone.")
                        .font(.body).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 60)

                    if coordinator.authPhase == .waitingForApproval && coordinator.activeAction == .unlockVault {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Waiting for iPhone approval…").foregroundStyle(.blue)
                        }
                    }

                    if coordinator.authPhase == .denied && coordinator.activeAction == nil {
                        Label("Access denied by iPhone", systemImage: "xmark.circle")
                            .foregroundStyle(.orange)
                    }

                    Button {
                        coordinator.requestVaultUnlock()
                    } label: {
                        Label("Unlock with Face ID", systemImage: "faceid")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(coordinator.pairedDevices.isEmpty || coordinator.authPhase == .waitingForApproval)

                    if coordinator.pairedDevices.isEmpty {
                        Label("Pair your iPhone first", systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle("Secure Vault")
    }
}

struct VaultCredentialRow: View {
    let service: String
    let username: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(service).fontWeight(.medium)
            HStack {
                Text(username).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.system(.caption, design: .monospaced)).foregroundStyle(.blue).textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
        Divider()
    }
}

// MARK: - Connection Status Card

struct MacConnectionStatusCard: View {
    let status: MacCoordinator.ConnectionStatus

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(statusColor.opacity(0.15)).frame(width: 48, height: 48)
                Image(systemName: statusIcon).font(.title3).foregroundStyle(statusColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("FaceBridge Status").font(.caption).foregroundStyle(.secondary)
                Text(status.rawValue).font(.title3).fontWeight(.semibold)
            }
            Spacer()
            Circle().fill(statusColor).frame(width: 10, height: 10)
                .shadow(color: statusColor.opacity(0.5), radius: 4)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusColor: Color {
        switch status {
        case .searching: return .orange
        case .deviceNearby: return .blue
        case .paired, .connectedSecurely: return .green
        }
    }

    private var statusIcon: String {
        switch status {
        case .searching: return "magnifyingglass"
        case .deviceNearby: return "antenna.radiowaves.left.and.right"
        case .paired: return "link"
        case .connectedSecurely: return "lock.shield.fill"
        }
    }
}

// MARK: - Devices View

struct MacDevicesView: View {
    @EnvironmentObject var coordinator: MacCoordinator
    @State private var showRemoveAllConfirmation = false

    var body: some View {
        Group {
            if coordinator.pairedDevices.isEmpty {
                ContentUnavailableView("No Trusted Devices", systemImage: "iphone.slash",
                                       description: Text("Pair a device to get started."))
            } else {
                List {
                    ForEach(coordinator.pairedDevices, id: \.id) { device in
                        HStack(spacing: 12) {
                            Image(systemName: device.platform == .iOS ? "iphone" : "laptopcomputer")
                                .font(.title3).foregroundStyle(.blue).frame(width: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.displayName).fontWeight(.medium)
                                Text("ID: \(device.id.uuidString.prefix(8))")
                                    .font(.caption2).foregroundStyle(.tertiary)
                                Text("Paired \(device.createdAt, style: .relative) ago")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                coordinator.removePairedDevice(device.id)
                            } label: {
                                Image(systemName: "trash").font(.caption)
                            }
                            .buttonStyle(.bordered).controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                    Section {
                        Button(role: .destructive) { showRemoveAllConfirmation = true } label: {
                            Label("Remove All Devices", systemImage: "trash.fill")
                        }
                    }
                }
                .alert("Remove All Devices?", isPresented: $showRemoveAllConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Remove All", role: .destructive) { coordinator.removeAllPairedDevices() }
                } message: {
                    Text("This will unpair all trusted devices. You will need to pair again.")
                }
            }
        }
        .navigationTitle("Trusted Devices")
    }
}

// MARK: - Pairing View

struct MacPairingView: View {
    @EnvironmentObject var coordinator: MacCoordinator

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "link.badge.plus").font(.system(size: 64)).foregroundStyle(.blue)
            Text("Pair a New Device").font(.title2).fontWeight(.semibold)
            Text("Generate a pairing code and enter it on your iPhone, or use one-tap pairing from the iPhone app.")
                .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 40)

            if !coordinator.pairingCode.isEmpty {
                Text(coordinator.pairingCode)
                    .font(.system(.largeTitle, design: .monospaced)).fontWeight(.bold).tracking(8)
                    .padding().background(.blue.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Text("State: \(coordinator.pairingState.rawValue)").font(.caption).foregroundStyle(.secondary)
            Button("Generate Pairing Code") { coordinator.generatePairingCode() }
                .buttonStyle(.borderedProminent).controlSize(.large)
            Spacer()
        }
        .padding()
        .navigationTitle("Pair New Device")
    }
}

// MARK: - Settings

struct MacSettingsView: View {
    @EnvironmentObject var coordinator: MacCoordinator

    var body: some View {
        Form {
            Section("Connection") {
                HStack {
                    Text("Status"); Spacer()
                    Text(coordinator.connectionStatus.rawValue).foregroundStyle(.secondary)
                }
            }
            Section("Developer") {
                Toggle("Developer Mode", isOn: $coordinator.developerModeEnabled)
            }
            Section("About") {
                HStack {
                    Text("Version"); Spacer()
                    Text("0.3.0-alpha").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}

// MARK: - Authorization Lab (Developer)

struct MacAuthLabView: View {
    @EnvironmentObject var coordinator: MacCoordinator
    @State private var customReason = "Test authorization request"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Protected Action Tests") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabButton(title: "Test Request Authorization", icon: "faceid") {
                            coordinator.requestAuthorization(reason: customReason)
                        }
                        LabButton(title: "Test Unlock Secure Vault", icon: "lock.shield") {
                            coordinator.requestVaultUnlock()
                        }
                        LabButton(title: "Test Demo Command", icon: "terminal") {
                            coordinator.requestDemoCommand()
                        }
                        LabButton(title: "Test Protected File", icon: "doc.text.magnifyingglass") {
                            coordinator.requestFileReveal()
                        }
                    }.padding(8)
                }

                GroupBox("Custom Request") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Reason", text: $customReason).textFieldStyle(.roundedBorder)
                        Button("Send Custom Request") {
                            coordinator.requestAuthorization(reason: customReason)
                        }.buttonStyle(.borderedProminent)
                    }.padding(8)
                }

                GroupBox("Current State") {
                    VStack(alignment: .leading, spacing: 6) {
                        StateRow(label: "Auth Phase", value: coordinator.authPhase.rawValue)
                        StateRow(label: "Active Action", value: coordinator.activeAction?.rawValue ?? "none")
                        StateRow(label: "Last Result", value: coordinator.lastAuthResult)
                        StateRow(label: "Vault", value: coordinator.isVaultUnlocked ? "Unlocked" : "Locked")
                        StateRow(label: "File", value: coordinator.isFileRevealed ? "Revealed" : "Hidden")
                        StateRow(label: "Demo Cmd", value: coordinator.demoCommandResult.isEmpty ? "—" : coordinator.demoCommandResult)
                        StateRow(label: "Transport Map", value: "\(coordinator.discoveredDevices.count) discovered, \(coordinator.mergedNearbyDevices.count) merged")
                        StateRow(label: "Paired", value: "\(coordinator.pairedDevices.count) device(s)")
                    }.padding(8)
                }

                GroupBox("Transport Details") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(coordinator.discoveredDevices, id: \.id) { device in
                            HStack {
                                Image(systemName: device.transportType == .ble ? "wave.3.right" : "wifi")
                                VStack(alignment: .leading) {
                                    Text(device.displayName).font(.caption)
                                    Text(device.id.uuidString.prefix(8)).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Send Auth") {
                                    coordinator.sendAuthorizationRequest(to: device.id, reason: customReason)
                                }.font(.caption).buttonStyle(.bordered)
                            }
                        }
                        if coordinator.discoveredDevices.isEmpty {
                            Text("No discovered devices").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(8)
                }

                GroupBox("Reset") {
                    HStack(spacing: 12) {
                        Button("Lock Vault") { coordinator.lockVault() }.buttonStyle(.bordered)
                        Button("Hide File") { coordinator.hideProtectedFile() }.buttonStyle(.bordered)
                        Button("Clear Result") {
                            coordinator.demoCommandResult = ""
                        }.buttonStyle(.bordered)
                    }.padding(8)
                }
            }.padding()
        }
        .navigationTitle("Authorization Lab")
    }
}

struct LabButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).frame(width: 24)
                Text(title)
                Spacer()
                Image(systemName: "arrow.right.circle").foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
    }
}

struct StateRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
            Text(value).font(.system(.caption, design: .monospaced))
            Spacer()
        }
    }
}

// MARK: - Debug Console

struct MacDebugView: View {
    @EnvironmentObject var coordinator: MacCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Console Log") {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(coordinator.logMessages) { entry in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(entry.timestamp, style: .time)
                                            .font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                                        Text("[\(entry.category)]")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(colorForCategory(entry.category))
                                        Text(entry.message)
                                            .font(.system(.caption2, design: .monospaced))
                                    }.id(entry.id)
                                }
                            }
                        }
                        .frame(height: 500)
                        .onChange(of: coordinator.logMessages.count) { _, _ in
                            if let last = coordinator.logMessages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }.padding(8)
                }
            }.padding()
        }
        .navigationTitle("Debug Console")
    }

    private func colorForCategory(_ cat: String) -> Color {
        switch cat {
        case "transport": return .blue
        case "pairing": return .orange
        case "authorization": return .green
        case "crypto": return .purple
        case "vault", "file", "action": return .mint
        case "routing": return .cyan
        case "lifecycle": return .gray
        default: return .primary
        }
    }
}
#endif
