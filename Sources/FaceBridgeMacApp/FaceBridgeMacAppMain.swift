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
        }

        MenuBarExtra("FaceBridge", systemImage: "faceid") {
            Text("FaceBridge")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
#else
import SwiftUI

@main
struct FaceBridgeMacAppMain: App {
    var body: some Scene {
        WindowGroup {
            Text("FaceBridgeMacApp requires macOS")
        }
    }
}
#endif
