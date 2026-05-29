import SwiftUI

@main
struct Gen4SpinningApp: App {
    @StateObject private var session = BtSessionManager()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                SelectMachineView()
                    .environmentObject(session)
            }
        }
    }
}
