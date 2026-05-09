import SwiftUI

@main
struct N3xtNVRApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
