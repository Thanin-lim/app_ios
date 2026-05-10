import SwiftUI

@main
struct MinIODashboardApp: App {

    @StateObject private var state = AppState()

    var body: some Scene {

        WindowGroup {

            ContentView()
                .environmentObject(state)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
        }

        #if os(macOS)

        .windowStyle(.titleBar)

        #endif
    }
}
