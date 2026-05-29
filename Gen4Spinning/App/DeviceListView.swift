import SwiftUI
import CoreBluetooth

struct DeviceListView: View {
    let machineType: MachineType
    @EnvironmentObject private var session: BtSessionManager

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [SpinColors.blue, SpinColors.lightGreen],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 56)
                .overlay(
                    Text("Select Device").font(.title2).fontWeight(.bold).foregroundColor(.white)
                )

            Group {
                switch session.connectionState {
                case .connecting(let name), .reconnecting(let name):
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Connecting to \(name)…").foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)

                case .connected:
                    dashboardView()

                case .lost(let name):
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.slash").font(.system(size: 44)).foregroundColor(.red)
                        Text("Connection lost to \(name)").foregroundColor(.secondary)
                        GradientButton(text: "Reconnect", action: { session.reconnect() })
                            .padding(.horizontal, 40)
                    }
                    .frame(maxHeight: .infinity)

                default:
                    deviceList
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear  { session.refreshAccessories() }
        .onDisappear { session.stopScan() }
    }

    // MARK: - Device list

    @ViewBuilder private var deviceList: some View {
        if session.availablePeripherals.isEmpty {
            VStack(spacing: 16) {
                ProgressView()
                Text("Scanning for Gen4 machines…")
                    .font(.headline).foregroundColor(.secondary)
                Text("Make sure the machine is powered on\nand Bluetooth is enabled.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
                Button("Scan Again") { session.refreshAccessories() }
                    .foregroundColor(SpinColors.blue)
            }
            .frame(maxHeight: .infinity)
        } else {
            List(session.availablePeripherals, id: \.identifier) { peripheral in
                Button(action: { session.connect(to: peripheral) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(peripheral.name ?? "Gen4 Machine")
                                .font(.headline).foregroundColor(.primary)
                            Text(peripheral.identifier.uuidString)
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Dashboard router

    @ViewBuilder private func dashboardView() -> some View {
        switch machineType {
        case .carding:   CardingDashboard(session: session)
        case .drawFrame: DfDashboard(session: session)
        case .flyer:     FlyerDashboard(session: session)
        case .ring:      RingDashboard(session: session)
        }
    }
}
