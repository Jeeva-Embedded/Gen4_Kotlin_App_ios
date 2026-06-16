import SwiftUI

struct RingDashboard: View {
    @StateObject private var vm: RingViewModel
    @State private var selectedTab = 0
    @State private var showPid = false
    private let session: BtSessionManager

    init(session: BtSessionManager) {
        self.session = session
        _vm = StateObject(wrappedValue: RingViewModel(session: session))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ring / Doubler").font(.headline).fontWeight(.bold).foregroundColor(SpinColors.blue)
                Spacer()
                Button(action: { vm.disconnect() }) {
                    Text("Disconnect").font(.subheadline).foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(.systemGroupedBackground))
            Divider()

            Picker("", selection: $selectedTab) {
                Text("Settings").tag(0); Text("Status").tag(1)
                Text("Options").tag(2); Text("Tests").tag(3)
            }
            .pickerStyle(.segmented).padding(.horizontal, 12).padding(.vertical, 6)
            Divider()

            Group {
                switch selectedTab {
                case 0: RingSettingsView(vm: vm, onNavigatePid: { showPid = true })
                case 1: RingStatusView(vm: vm)
                case 2: RingOptionsView(vm: vm)
                case 3: RingTestsView(vm: vm)
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showPid) {
            PidView(machine: "ring", session: session)
        }
    }
}
