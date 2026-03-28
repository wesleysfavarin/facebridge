import SwiftUI
import FaceBridgeCore
import FaceBridgeSharedUI

public struct iOSMainView: View {
    @State private var selectedTab = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            iOSDevicesView()
                .tabItem {
                    Label("Devices", systemImage: "laptopcomputer.and.iphone")
                }
                .tag(0)

            iOSPairingScannerView()
                .tabItem {
                    Label("Pair", systemImage: "qrcode.viewfinder")
                }
                .tag(1)

            iOSSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
}

struct iOSDevicesView: View {
    @State private var devices: [DeviceIdentity] = []

    var body: some View {
        NavigationStack {
            TrustedDevicesListView(devices: devices) { device in
                devices.removeAll { $0.id == device.id }
            }
            .navigationTitle("Trusted Devices")
        }
    }
}

struct iOSPairingScannerView: View {
    @State private var isScanning = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                PairingCodeView(code: "", isScanning: isScanning)

                Button(isScanning ? "Stop Scanning" : "Start Scanning") {
                    isScanning.toggle()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Pair Device")
        }
    }
}

struct iOSSettingsView: View {
    @State private var requireProximity = false
    @State private var sessionTimeout: Double = 30
    @State private var minimumRSSI: Double = -70

    var body: some View {
        NavigationStack {
            PolicySettingsView(
                requireProximity: $requireProximity,
                sessionTimeout: $sessionTimeout,
                minimumRSSI: $minimumRSSI
            )
            .navigationTitle("Settings")
        }
    }
}
