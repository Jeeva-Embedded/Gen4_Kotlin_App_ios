import SwiftUI

private struct CarouselPage {
    let label: String
    let motorId: UInt8
}

private let flyerPages: [CarouselPage] = [
    .init(label: "Production",   motorId: 0x0A),
    .init(label: "Flyer",        motorId: 0x01),
    .init(label: "Bobbin",       motorId: 0x02),
    .init(label: "Front Roller", motorId: 0x03),
    .init(label: "Back Roller",  motorId: 0x04),
    .init(label: "Lift Left",    motorId: 0x08),
    .init(label: "Lift Right",   motorId: 0x09),
]

struct FlyerCarouselView: View {
    @ObservedObject var vm: FlyerViewModel
    @State private var currentPage = 0

    // Auto-refresh timer
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $currentPage) {
                ForEach(Array(flyerPages.enumerated()), id: \.offset) { idx, page in
                    let data = vm.carouselData[page.motorId] ?? [:]
                    CarouselCard(title: page.label,
                                 isProduction: page.motorId == 0x0A,
                                 data: data)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 200)

            // Dot indicators
            HStack(spacing: 6) {
                ForEach(0..<flyerPages.count, id: \.self) { i in
                    Circle()
                        .fill(currentPage == i ? SpinColors.lightGreen : Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .onReceive(timer) { _ in
            let motorId = flyerPages[currentPage].motorId
            vm.sendCarouselRequest(motorId: motorId)
        }
    }
}

private struct CarouselCard: View {
    let title: String
    let isProduction: Bool
    let data: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline).foregroundColor(SpinColors.blue)
                .frame(maxWidth: .infinity, alignment: .center)

            if isProduction {
                carouselRow("Output (m)",     data["outputMtrs"] ?? "-")
                carouselRow("Total Power (W)", data["totalPower"] ?? "-")
            } else {
                carouselRow("RPM",            data["rpm"]        ?? "-")
                carouselRow("Current (A)",    data["current"]    ?? "-")
                carouselRow("Motor Temp (°C)", data["motorTemp"] ?? "-")
                carouselRow("MOSFET Temp (°C)", data["mosfetTemp"] ?? "-")
                carouselRow("Output (m)",     data["outputMtrs"] ?? "-")
                carouselRow("Power (W)",      data["totalPower"] ?? "-")
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func carouselRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption).fontWeight(.semibold)
        }
    }
}
