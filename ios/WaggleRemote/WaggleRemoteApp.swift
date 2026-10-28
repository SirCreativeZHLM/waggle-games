import SwiftUI

@main
struct WaggleRemoteApp: App {
    @StateObject private var remote = RemoteController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(remote)
                .preferredColorScheme(.light)
        }
    }
}
