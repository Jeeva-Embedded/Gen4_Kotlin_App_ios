import SwiftUI

private let cardingMotors: [(label: String, motorId: UInt8)] = [
    ("Cylinder", 0x01), ("Beater", 0x02), ("Cage", 0x03),
    ("Card Feed", 0x04), ("Beater Feed", 0x05), ("Coiler", 0x06), ("Picker Cylinder", 0x07),
]

struct CardingTestsView: View {
    @ObservedObject var vm: CardingViewModel
    @State private var selectedIdx: Int? = nil
    @State private var direction: UInt8 = 0x01
    @State private var speedPct:  Double = 50
    @State private var duration:  Double = 5

    var body: some View {
        VStack(spacing: 0) {
            List(Array(cardingMotors.enumerated()), id: \.offset) { idx, motor in
                Button(action: { selectedIdx = idx }) {
                    HStack {
                        Text(motor.label).foregroundColor(.primary)
                        Spacer()
                        if selectedIdx == idx { Image(systemName: "checkmark").foregroundColor(SpinColors.blue) }
                    }
                }
            }
            .listStyle(.plain).frame(maxHeight: 220)

            Divider()

            if let idx = selectedIdx {
                let motor = cardingMotors[idx]
                ScrollView {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Direction:").font(.subheadline).foregroundColor(SpinColors.blue)
                            Spacer()
                            Picker("", selection: $direction) {
                                Text("Forward").tag(UInt8(0x01))
                                Text("Reverse").tag(UInt8(0x02))
                            }.pickerStyle(.segmented).frame(width: 180)
                        }.padding(.horizontal)

                        HStack { Text("Speed %:").font(.subheadline).foregroundColor(SpinColors.blue); Spacer(); Text("\(Int(speedPct))").fontWeight(.semibold) }.padding(.horizontal)
                        Slider(value: $speedPct, in: 1...100, step: 1).padding(.horizontal)

                        HStack { Text("Duration (s):").font(.subheadline).foregroundColor(SpinColors.blue); Spacer(); Text("\(Int(duration))").fontWeight(.semibold) }.padding(.horizontal)
                        Slider(value: $duration, in: 1...60, step: 1).padding(.horizontal)

                        if vm.diagnosisState.isDiagnosing {
                            let d = vm.diagnosisState
                            VStack(spacing: 4) {
                                diagRow("RPM", d.rpm); diagRow("PWM", d.pwm)
                                diagRow("Current", d.current); diagRow("Power", d.power)
                            }
                            .padding(12).background(Color(.secondarySystemGroupedBackground)).cornerRadius(8).padding(.horizontal)
                        }

                        HStack(spacing: 8) {
                            GradientButton(text: "START", action: {
                                vm.startDiagnosis(motorLabel: motor.label)
                                vm.sendDiagnostic(motorId: motor.motorId, controlType: 0x01,
                                                  direction: direction, speedPct: Int(speedPct), durationSec: Int(duration))
                            })
                            GradientButton(text: "STOP", action: { vm.sendStopDiagnosis(); vm.clearDiagnosis() })
                        }.padding(.horizontal)
                    }.padding(.vertical, 12)
                }
            } else {
                Text("Select a motor above").foregroundColor(.secondary).padding(.top, 20)
                Spacer()
            }
        }
    }

    private func diagRow(_ l: String, _ v: String) -> some View {
        HStack { Text(l).font(.subheadline).foregroundColor(.secondary); Spacer(); Text(v).font(.subheadline).fontWeight(.semibold) }
    }
}
