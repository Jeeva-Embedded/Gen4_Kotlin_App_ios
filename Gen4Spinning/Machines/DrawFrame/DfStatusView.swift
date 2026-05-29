import SwiftUI

private let dfCarouselPages: [(label: String, motorId: UInt8)] = [
    ("Production", 0x0A), ("Front Roller", 0x01), ("Back Roller", 0x02), ("Creel", 0x03),
]

struct DfStatusView: View {
    @ObservedObject var vm: DfViewModel

    private var ss: UInt8    { vm.runState.substate }
    private var isRunning: Bool { ss == 0x01 }
    private var isPaused:  Bool { ss == 0x02 }
    private var isError:   Bool { ss == 0x03 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                StatusBox(label: "Status", value: substateLabel(ss))

                if isRunning {
                    StatusBox(label: "Length (m)",
                              value: String(format: "%.1f m", vm.runState.currentLength))
                    let speed = vm.runState.deliveryMtrsPerMin > 0
                        ? String(format: "%.1f m/min", vm.runState.deliveryMtrsPerMin)
                        : "\(vm.settings.deliverySpeed) m/min"
                    StatusBox(label: "Delivery (m/min)", value: speed)
                    StatusBox(
                        label: "Auto Leveller",
                        value: vm.runState.alSensorActive ? "ON" : "OFF",
                        valueColor: vm.runState.alSensorActive ? SpinColors.lightGreen : SpinColors.red
                    )
                    DfCarouselView(vm: vm)
                } else if isPaused {
                    StatusBox(label: "Length (m)",
                              value: String(format: "%.1f m", vm.runState.currentLength))
                    if !vm.runState.pauseReason.isEmpty {
                        StatusBox(label: "Pause Reason", value: vm.runState.pauseReason)
                    }
                    if vm.runState.pauseLength != 0 {
                        StatusBox(label: "Pause Length",
                                  value: String(format: "%.1f m", vm.runState.pauseLength))
                    }
                    StatusBox(
                        label: "Auto Leveller",
                        value: vm.runState.alSensorActive ? "ON" : "OFF",
                        valueColor: vm.runState.alSensorActive ? SpinColors.lightGreen : SpinColors.red
                    )
                } else if isError {
                    StatusBox(label: "Current Length",
                              value: String(format: "%.1f m", vm.runState.currentLength))
                    StatusBox(label: "Error Information",
                              value: vm.runState.errorReason.isEmpty ? "-" : vm.runState.errorReason)
                    StatusBox(label: "Error Source",
                              value: vm.runState.errorSource.isEmpty ? "-" : vm.runState.errorSource)
                }
            }
            .padding(16)
        }
    }

    private func substateLabel(_ s: UInt8) -> String {
        switch s {
        case 0x00: return "IDLE"; case 0x01: return "RUNNING"; case 0x02: return "PAUSED"
        case 0x03: return "ERROR"; case 0x04: return "HOMING"; case 0x05: return "INCHING"
        case 0x06: return "CAN OVER"; default: return "UNKNOWN"
        }
    }
}

// MARK: - DF Carousel

struct DfCarouselView: View {
    @ObservedObject var vm: DfViewModel
    @State private var currentPage = 0
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $currentPage) {
                ForEach(Array(dfCarouselPages.enumerated()), id: \.offset) { idx, page in
                    let data = vm.carouselData[page.motorId] ?? [:]
                    DfCarouselCard(title: page.label, isProduction: page.motorId == 0x0A, data: data)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 160)

            HStack(spacing: 6) {
                ForEach(0..<dfCarouselPages.count, id: \.self) { i in
                    Circle()
                        .fill(currentPage == i ? SpinColors.lightGreen : Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .onReceive(timer) { _ in
            vm.sendCarouselRequest(motorId: dfCarouselPages[currentPage].motorId)
        }
    }
}

private struct DfCarouselCard: View {
    let title: String; let isProduction: Bool; let data: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundColor(SpinColors.blue)
                .frame(maxWidth: .infinity, alignment: .center)
            if isProduction {
                row("Output (m)",      data["outputMtrs"]  ?? "-")
                row("Total Power (W)", data["totalPower"]  ?? "-")
            } else {
                row("RPM",             data["rpm"]         ?? "-")
                row("Current (A)",     data["current"]     ?? "-")
                row("Motor Temp",      data["motorTemp"]   ?? "-")
                row("MOSFET Temp",     data["mosfetTemp"]  ?? "-")
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .padding(.horizontal, 8)
    }

    private func row(_ l: String, _ v: String) -> some View {
        HStack {
            Text(l).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(v).font(.caption).fontWeight(.semibold)
        }
    }
}
