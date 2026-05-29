import SwiftUI

enum MachineType: String, CaseIterable {
    case carding    = "Carding"
    case drawFrame  = "Draw Frame"
    case flyer      = "Flyer Frame"
    case ring       = "Ring / Doubler"
}

struct SelectMachineView: View {
    @EnvironmentObject private var session: BtSessionManager

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [SpinColors.blue, SpinColors.lightGreen],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 56)
                .overlay(
                    Text("Gen4 Spinning")
                        .font(.title2).fontWeight(.bold).foregroundColor(.white)
                )

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(MachineType.allCases, id: \.self) { machine in
                        NavigationLink(destination: DeviceListView(machineType: machine)
                            .environmentObject(session)) {
                            machineTile(machine.rawValue)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 24)
            }
        }
        .navigationBarHidden(true)
    }

    private func machineTile(_ name: String) -> some View {
        HStack {
            Text(name).font(.title3).fontWeight(.medium).foregroundColor(SpinColors.blue)
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(SpinColors.blue)
        }
        .padding(.horizontal, 20).padding(.vertical, 18)
        .background(Color(.systemBackground))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(SpinColors.blue, lineWidth: 1.5))
        .cornerRadius(14)
    }
}
