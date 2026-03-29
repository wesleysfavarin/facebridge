import SwiftUI
import FaceBridgeCore

@main
struct FaceBridgeiOSAppMain: App {
    @StateObject private var coordinator = iOSCoordinator()

    var body: some Scene {
        WindowGroup {
            iOSMainView()
                .environmentObject(coordinator)
                .onAppear { coordinator.start() }
        }
    }
}
