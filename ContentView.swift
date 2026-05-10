import SwiftUI

struct ContentView: View {
    @StateObject private var state = AppState()

    var body: some View {
        Group {
            if state.isLoggedIn {
                MainView()
            } else {
                LoginView()
            }
        }
        .environmentObject(state)
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 650)
        #endif
    }
}
