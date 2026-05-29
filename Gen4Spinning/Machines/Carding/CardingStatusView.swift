import SwiftUI

struct CardingStatusView: View {
    @ObservedObject var vm: CardingViewModel

    private var ss: UInt8 { vm.runState.substate }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                StatusBox(label: "Status", value: substateLabel(ss))

                switch ss {
                case 0x01:
                    let speed = vm.runState.deliveryMtrsPerMin > 0
                        ? String(format: "%.1f m/min", vm.runState.deliveryMtrsPerMin)
                        : "\(vm.settings.deliverySpeed) m/min"
                    StatusBox(label: "Delivery Speed", value: speed)
                    HStack(spacing: 24) {
                        // coilerSensor → "Carding Duct"  |  ductSensor → "Auto Feed Duct"  (matches Flutter naming)
                        SensorIndicator(label: "Carding Duct",   active: vm.runState.coilerSensor)
                        SensorIndicator(label: "Auto Feed Duct", active: vm.runState.ductSensor)
                    }
                    .frame(maxWidth: .infinity)
                    CardingCarouselView(vm: vm)

                case 0x02:
                    HStack(spacing: 24) {
                        SensorIndicator(label: "Carding Duct",   active: vm.runState.coilerSensor)
                        SensorIndicator(label: "Auto Feed Duct", active: vm.runState.ductSensor)
                    }.frame(maxWidth: .infinity)
                    if !vm.runState.pauseReason.isEmpty {
                        StatusBox(label: "Reason For Pause", value: vm.runState.pauseReason)
                    }

                case 0x03:
                    StatusBox(label: "Error Information",
                              value: "\(vm.runState.errorInformation) (\(vm.runState.errorCode))")
                    StatusBox(label: "Error Source", value: vm.runState.errorSource)

                case 0x04:
                    HStack(spacing: 24) {
                        SensorIndicator(label: "Carding Duct",   active: vm.runState.coilerSensor)
                        SensorIndicator(label: "Auto Feed Duct", active: vm.runState.ductSensor)
                    }.frame(maxWidth: .infinity)

                default: EmptyView()
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

// MARK: - Carding Carousel

private let cardingPages: [(label: String, motorId: UInt8)] = [
    ("Production", 0x0A), ("Cylinder", 0x01), ("Beater", 0x02),
    ("Cage", 0x03), ("Card Feed", 0x04), ("Beater Feed", 0x05), ("Coiler", 0x06),
]

struct CardingCarouselView: View {
    @ObservedObject var vm: CardingViewModel
    @State private var currentPage = 0
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $currentPage) {
                ForEach(Array(cardingPages.enumerated()), id: \.offset) { idx, page in
                    let data = vm.carouselData[page.motorId] ?? [:]
                    CardingCarouselCard(title: page.label,
                                       isProduction: page.motorId == 0x0A, data: data).tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never)).frame(height: 180)

            HStack(spacing: 6) {
                ForEach(0..<cardingPages.count, id: \.self) { i in
                    Circle().fill(currentPage == i ? SpinColors.lightGreen : Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .onReceive(timer) { _ in vm.sendCarouselRequest(motorId: cardingPages[currentPage].motorId) }
    }
}

private struct CardingCarouselCard: View {
    let title: String; let isProduction: Bool; let data: [String: String]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundColor(SpinColors.blue).frame(maxWidth: .infinity, alignment: .center)
            if isProduction {
                row("Output (m)", data["outputMtrs"] ?? "-")
                row("Total Power (W)", data["totalPower"] ?? "-")
            } else {
                row("RPM", data["rpm"] ?? "-"); row("Current (A)", data["current"] ?? "-")
                row("Motor Temp", data["motorTemp"] ?? "-"); row("Power (W)", data["totalPower"] ?? "-")
            }
        }
        .padding(12).background(Color(.secondarySystemGroupedBackground)).cornerRadius(10).padding(.horizontal, 8)
    }
    private func row(_ l: String, _ v: String) -> some View {
        HStack { Text(l).font(.caption).foregroundColor(.secondary); Spacer(); Text(v).font(.caption).fontWeight(.semibold) }
    }
}
