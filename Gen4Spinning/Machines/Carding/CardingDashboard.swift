import SwiftUI

struct CardingDashboard: View {
    @StateObject private var vm: CardingViewModel
    @State private var selectedTab = 0

    init(session: BtSessionManager) {
        _vm = StateObject(wrappedValue: CardingViewModel(session: session))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Carding").font(.headline).fontWeight(.bold).foregroundColor(SpinColors.blue)
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
                case 0: CardingSettingsView(vm: vm, onNavigatePid: {})
                case 1: CardingStatusView(vm: vm)
                case 2: CardingOptionsView(vm: vm)
                case 3: CardingTestsView(vm: vm)
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarHidden(true)
    }
}
