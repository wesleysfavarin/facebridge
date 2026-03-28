import SwiftUI

@main
struct FaceBridgeMacAppMain: App {
    var body: some Scene {
        WindowGroup {
            MacMainView()
        }

        #if os(macOS)
        MenuBarExtra("FaceBridge", systemImage: "faceid") {
            Text("FaceBridge")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        #endif
    }
}
