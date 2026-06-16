import SwiftUI

struct FlyerDashboard: View {
    @StateObject private var vm: FlyerViewModel
    @State private var selectedTab = 0
    @State private var showPid = false
    private let session: BtSessionManager

    init(session: BtSessionManager) {
        self.session = session
        _vm = StateObject(wrappedValue: FlyerViewModel(session: session))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text("Flyer Frame")
                    .font(.headline).fontWeight(.bold)
                    .foregroundColor(SpinColors.blue)
                Spacer()
                Button(action: { vm.disconnect() }) {
                    Text("Disconnect")
                        .font(.subheadline).foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(.systemGroupedBackground))

            Divider()

            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Settings").tag(0)
                Text("Status").tag(1)
                Text("Options").tag(2)
                Text("Tests").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12).padding(.vertical, 6)

            Divider()

            // Content
            Group {
                switch selectedTab {
                case 0: FlyerSettingsView(vm: vm, onNavigatePid: { showPid = true })
                case 1: FlyerStatusView(vm: vm)
                case 2: FlyerOptionsView(vm: vm)
                case 3: FlyerTestsView(vm: vm)
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showPid) {
            PidView(machine: "flyer", session: session)
        }
    }
}
