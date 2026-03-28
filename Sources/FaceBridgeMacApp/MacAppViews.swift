import SwiftUI
import FaceBridgeCore
import FaceBridgeSharedUI

public struct MacMainView: View {
    @State private var selectedSection: MacSection = .devices

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(MacSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
            }
            .navigationTitle("FaceBridge")
        } detail: {
            switch selectedSection {
            case .devices:
                MacDevicesView()
            case .pairing:
                MacPairingView()
            case .auditLog:
                MacAuditLogView()
            case .settings:
                MacSettingsView()
            }
        }
    }
}

enum MacSection: String, CaseIterable, Identifiable, Hashable {
    case devices
    case pairing
    case auditLog
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .devices: return "Paired Devices"
        case .pairing: return "Pair New Device"
        case .auditLog: return "Audit Log"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .devices: return "iphone.and.arrow.forward"
        case .pairing: return "link.badge.plus"
        case .auditLog: return "list.clipboard"
        case .settings: return "gear"
        }
    }
}

struct MacDevicesView: View {
    @State private var devices: [DeviceIdentity] = []

    var body: some View {
        TrustedDevicesListView(devices: devices) { device in
            devices.removeAll { $0.id == device.id }
        }
        .navigationTitle("Paired Devices")
    }
}

struct MacPairingView: View {
    @State private var pairingCode = "000000"

    var body: some View {
        VStack {
            PairingCodeView(code: pairingCode)

            Button("Generate New Code") {
                pairingCode = String(format: "%06d", Int.random(in: 0...999_999))
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
        .navigationTitle("Pair New Device")
    }
}

struct MacAuditLogView: View {
    @State private var entries: [AuditEntry] = []

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Events",
                    systemImage: "list.clipboard",
                    description: Text("Authorization events will appear here.")
                )
            } else {
                Table(entries) {
                    TableColumn("Time") { entry in
                        Text(entry.timestamp, style: .time)
                    }
                    TableColumn("Event") { entry in
                        Text(entry.event.rawValue)
                    }
                    TableColumn("Details") { entry in
                        Text(entry.details ?? "—")
                    }
                }
            }
        }
        .navigationTitle("Audit Log")
    }
}

struct MacSettingsView: View {
    @State private var requireProximity = false
    @State private var sessionTimeout: Double = 30
    @State private var minimumRSSI: Double = -70

    var body: some View {
        PolicySettingsView(
            requireProximity: $requireProximity,
            sessionTimeout: $sessionTimeout,
            minimumRSSI: $minimumRSSI
        )
        .navigationTitle("Settings")
    }
}
