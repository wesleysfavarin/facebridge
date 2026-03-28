import SwiftUI

public struct PairingCodeView: View {
    let code: String
    let isScanning: Bool

    public init(code: String, isScanning: Bool = false) {
        self.code = code
        self.isScanning = isScanning
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isScanning ? "qrcode.viewfinder" : "qrcode")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            if isScanning {
                Text("Scanning for devices…")
                    .font(.headline)

                ProgressView()
            } else {
                Text("Pairing Code")
                    .font(.headline)

                Text(code)
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.bold)
                    .tracking(6)

                Text("Enter this code on your iPhone to pair.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
