import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        Group {
            if session.isConnected {
                MainDashboardView()
            } else {
                LoginView()
            }
        }
        .frame(minWidth: 960, minHeight: 640)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSession())
}
