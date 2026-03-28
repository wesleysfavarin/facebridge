import SwiftUI
import FaceBridgeCore

public struct PolicySettingsView: View {
    @Binding var requireProximity: Bool
    @Binding var sessionTimeout: Double
    @Binding var minimumRSSI: Double

    public init(
        requireProximity: Binding<Bool>,
        sessionTimeout: Binding<Double>,
        minimumRSSI: Binding<Double>
    ) {
        self._requireProximity = requireProximity
        self._sessionTimeout = sessionTimeout
        self._minimumRSSI = minimumRSSI
    }

    public var body: some View {
        Form {
            Section("Security") {
                Toggle("Require Proximity", isOn: $requireProximity)

                VStack(alignment: .leading) {
                    Text("Session Timeout: \(Int(sessionTimeout))s")
                    Slider(value: $sessionTimeout, in: 10...120, step: 5)
                }

                if requireProximity {
                    VStack(alignment: .leading) {
                        Text("Minimum Signal Strength: \(Int(minimumRSSI)) dBm")
                        Slider(value: $minimumRSSI, in: -90...(-30), step: 5)
                    }
                }
            }
        }
    }
}
