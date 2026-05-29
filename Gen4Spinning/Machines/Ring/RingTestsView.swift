import SwiftUI

private struct RingMotorEntry {
    let label: String; let motorId: UInt8; let isLift: Bool
}

private let ringMotors: [RingMotorEntry] = [
    RingMotorEntry(label: "Calender",   motorId: 0x01, isLift: false),
    RingMotorEntry(label: "Lift",       motorId: 0x07, isLift: true),
    RingMotorEntry(label: "Lift Left",  motorId: 0x08, isLift: true),
    RingMotorEntry(label: "Lift Right", motorId: 0x09, isLift: true),
]

struct RingTestsView: View {
    @ObservedObject var vm: RingViewModel
    @State private var selectedIdx: Int?   = nil
    @State private var controlType: UInt8 = 0x01
    @State private var direction:   UInt8 = 0x01   // for non-lift motors
    @State private var liftCmd:     UInt8 = 0x00   // 0=Up, 1=Down, 2=Stop
    @State private var speedPct:    Double = 50
    @State private var duration:    Double = 5
    @State private var bedDist:     Double = 10

    var body: some View {
        VStack(spacing: 0) {
            List(Array(ringMotors.enumerated()), id: \.offset) { idx, motor in
                Button(action: { selectedIdx = idx }) {
                    HStack {
                        Text(motor.label).foregroundColor(.primary)
                        Spacer()
                        if selectedIdx == idx {
                            Image(systemName: "checkmark").foregroundColor(SpinColors.blue)
                        }
                    }
                }
            }
            .listStyle(.plain).frame(maxHeight: 180)

            Divider()

            if let idx = selectedIdx {
                let motor = ringMotors[idx]
                ScrollView {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Control:").font(.subheadline).foregroundColor(SpinColors.blue)
                            Spacer()
                            Picker("", selection: $controlType) {
                                Text("Open Loop").tag(UInt8(0x01))
                                Text("Closed Loop").tag(UInt8(0x02))
                            }.pickerStyle(.segmented).frame(width: 200)
                        }.padding(.horizontal)

                        if motor.isLift {
                            HStack {
                                Text("Lift Command:").font(.subheadline).foregroundColor(SpinColors.blue)
                                Spacer()
                                Picker("", selection: $liftCmd) {
                                    Text("Up").tag(UInt8(0x00))
                                    Text("Down").tag(UInt8(0x01))
                                    Text("Stop").tag(UInt8(0x02))
                                }.pickerStyle(.segmented).frame(width: 200)
                            }.padding(.horizontal)

                            HStack {
                                Text("Bed Dist (mm):").font(.subheadline).foregroundColor(SpinColors.blue)
                                Spacer()
                                Text("\(Int(bedDist))").fontWeight(.semibold)
                            }.padding(.horizontal)
                            Slider(value: $bedDist, in: 1...200, step: 1).padding(.horizontal)
                        } else {
                            HStack {
                                Text("Direction:").font(.subheadline).foregroundColor(SpinColors.blue)
                                Spacer()
                                Picker("", selection: $direction) {
                                    Text("Default").tag(UInt8(0x01))
                                    Text("Reverse").tag(UInt8(0x02))
                                }.pickerStyle(.segmented).frame(width: 180)
                            }.padding(.horizontal)
                        }

                        HStack {
                            Text("Speed %:").font(.subheadline).foregroundColor(SpinColors.blue)
                            Spacer()
                            Text("\(Int(speedPct))").fontWeight(.semibold)
                        }.padding(.horizontal)
                        Slider(value: $speedPct, in: 1...100, step: 1).padding(.horizontal)

                        HStack {
                            Text("Duration (s):").font(.subheadline).foregroundColor(SpinColors.blue)
                            Spacer()
                            Text("\(Int(duration))").fontWeight(.semibold)
                        }.padding(.horizontal)
                        Slider(value: $duration, in: 1...60, step: 1).padding(.horizontal)

                        if vm.diagnosisState.isDiagnosing {
                            let d = vm.diagnosisState
                            VStack(spacing: 4) {
                                diagRow("RPM",     d.rpm);   diagRow("PWM",     d.pwm)
                                diagRow("Current", d.current); diagRow("Power", d.power)
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(8).padding(.horizontal)
                        }

                        HStack(spacing: 8) {
                            GradientButton(text: "START", action: {
                                vm.startDiagnosis(motorLabel: motor.label)
                                let dir = motor.isLift ? liftCmd : direction
                                let bed = motor.isLift ? Int(bedDist) : nil
                                vm.sendDiagnostic(motorId: motor.motorId, controlType: controlType,
                                                  direction: dir, speedPct: Int(speedPct),
                                                  durationSec: Int(duration), bedDistanceMm: bed)
                            })
                            GradientButton(text: "STOP", action: {
                                vm.sendStopDiagnosis(); vm.clearDiagnosis()
                            })
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
        HStack {
            Text(l).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(v).font(.subheadline).fontWeight(.semibold)
        }
    }
}
