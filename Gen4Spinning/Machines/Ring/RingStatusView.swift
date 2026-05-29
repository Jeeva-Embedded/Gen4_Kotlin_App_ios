import SwiftUI

private let ringCarouselPages: [(label: String, motorId: UInt8)] = [
    ("Production", 0x0A), ("Calender", 0x01), ("Lift Left", 0x08), ("Lift Right", 0x09),
]

struct RingStatusView: View {
    @ObservedObject var vm: RingViewModel

    private var ss: UInt8    { vm.runState.substate }
    private var isRunning: Bool { ss == 0x01 }
    private var isPaused:  Bool { ss == 0x02 }
    private var isError:   Bool { ss == 0x03 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                StatusBox(label: "Status",
                          value: ss == 0x00 ? "--" : substateLabel(ss))

                if isRunning {
                    StatusBox(label: "Doff Percent",
                              value: String(format: "%.1f %%", vm.runState.weight))
                    RingCarouselView(vm: vm)
                } else if isPaused {
                    StatusBox(label: "Doff Percent",
                              value: String(format: "%.1f %%", vm.runState.weight))
                    if !vm.runState.pauseReason.isEmpty {
                        StatusBox(label: "Pause Reason", value: vm.runState.pauseReason)
                    }
                } else if isError {
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
        case 0x01: return "RUNNING"; case 0x02: return "PAUSED"
        case 0x03: return "ERROR";   case 0x04: return "HOMING"
        default:   return "UNKNOWN"
        }
    }
}

// MARK: - Ring Carousel

struct RingCarouselView: View {
    @ObservedObject var vm: RingViewModel
    @State private var currentPage = 0
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $currentPage) {
                ForEach(Array(ringCarouselPages.enumerated()), id: \.offset) { idx, page in
                    let data = vm.carouselData[page.motorId] ?? [:]
                    RingCarouselCard(title: page.label, isProduction: page.motorId == 0x0A, data: data)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 160)

            HStack(spacing: 6) {
                ForEach(0..<ringCarouselPages.count, id: \.self) { i in
                    Circle()
                        .fill(currentPage == i ? SpinColors.lightGreen : Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .onReceive(timer) { _ in
            vm.sendCarouselRequest(motorId: ringCarouselPages[currentPage].motorId)
        }
    }
}

private struct RingCarouselCard: View {
    let title: String; let isProduction: Bool; let data: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundColor(SpinColors.blue)
                .frame(maxWidth: .infinity, alignment: .center)
            if isProduction {
                row("m/Spindle",       data["outputMtrs"]  ?? "-")
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
