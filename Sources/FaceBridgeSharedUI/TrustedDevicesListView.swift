import SwiftUI
import FaceBridgeCore

public struct TrustedDevicesListView: View {
    let devices: [DeviceIdentity]
    let onRevoke: (DeviceIdentity) -> Void

    public init(devices: [DeviceIdentity], onRevoke: @escaping (DeviceIdentity) -> Void) {
        self.devices = devices
        self.onRevoke = onRevoke
    }

    public var body: some View {
        Group {
            if devices.isEmpty {
                ContentUnavailableView(
                    "No Trusted Devices",
                    systemImage: "iphone.slash",
                    description: Text("Pair a device to get started.")
                )
            } else {
                List {
                    ForEach(devices, id: \.id) { device in
                        DeviceCardView(
                            device: device,
                            isTrusted: true,
                            onRevoke: { onRevoke(device) }
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}
