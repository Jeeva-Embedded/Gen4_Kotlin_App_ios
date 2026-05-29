import SwiftUI

private struct MotorEntry: Identifiable {
    let id = UUID()
    let label: String
    let motorId: UInt8
    let isLift: Bool
}

private let flyerMotors: [MotorEntry] = [
    .init(label: "Flyer",        motorId: 0x01, isLift: false),
    .init(label: "Bobbin",       motorId: 0x02, isLift: false),
    .init(label: "Front Roller", motorId: 0x03, isLift: false),
    .init(label: "Back Roller",  motorId: 0x04, isLift: false),
    .init(label: "Lift Left",    motorId: 0x08, isLift: true),
    .init(label: "Lift Right",   motorId: 0x09, isLift: true),
]

struct FlyerTestsView: View {
    @ObservedObject var vm: FlyerViewModel
    @State private var selectedMotor: MotorEntry? = nil
    @State private var direction:  UInt8 = 0x01
    @State private var speedPct:   Double = 50
    @State private var durationSec: Double = 5
    @State private var bedDistMm:  Double = 10

    var body: some View {
        VStack(spacing: 0) {
            // Motor list
            List(flyerMotors) { motor in
                Button(action: { selectedMotor = motor }) {
                    HStack {
                        Text(motor.label).foregroundColor(.primary)
                        Spacer()
                        if selectedMotor?.id == motor.id {
                            Image(systemName: "checkmark").foregroundColor(SpinColors.blue)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: 200)

            Divider()

            if let motor = selectedMotor {
                ScrollView {
                    VStack(spacing: 12) {
                        // Direction
                        HStack {
                            Text("Direction:").font(.subheadline).foregroundColor(SpinColors.blue)
                            Spacer()
                            Picker("", selection: $direction) {
                                Text("Forward").tag(UInt8(0x01))
                                Text("Reverse").tag(UInt8(0x02))
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }
                        .padding(.horizontal)

                        if !motor.isLift {
                            HStack {
                                Text("Speed %:").font(.subheadline).foregroundColor(SpinColors.blue)
                                Spacer()
                                Text("\(Int(speedPct))").font(.subheadline).fontWeight(.semibold)
                            }.padding(.horizontal)
                            Slider(value: $speedPct, in: 1...100, step: 1).padding(.horizontal)

                            HStack {
                                Text("Duration (s):").font(.subheadline).foregroundColor(SpinColors.blue)
                                Spacer()
                                Text("\(Int(durationSec))").font(.subheadline).fontWeight(.semibold)
                            }.padding(.horizontal)
                            Slider(value: $durationSec, in: 1...60, step: 1).padding(.horizontal)
                        } else {
                            HStack {
                                Text("Bed Distance (mm):").font(.subheadline).foregroundColor(SpinColors.blue)
                                Spacer()
                                Text("\(Int(bedDistMm))").font(.subheadline).fontWeight(.semibold)
                            }.padding(.horizontal)
                            Slider(value: $bedDistMm, in: 1...100, step: 1).padding(.horizontal)
                        }

                        // Results
                        if vm.diagnosisState.isDiagnosing {
                            let d = vm.diagnosisState
                            VStack(spacing: 6) {
                                diagRow("RPM",     d.rpm)
                                diagRow("PWM",     d.pwm)
                                diagRow("Current", d.current)
                                diagRow("Power",   d.power)
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }

                        HStack(spacing: 8) {
                            GradientButton(text: "START", action: {
                                vm.startDiagnosis(motorLabel: motor.label)
                                if motor.isLift {
                                    vm.sendDiagnostic(motorId: motor.motorId, controlType: 0x01,
                                                      direction: direction, speedPct: 0, durationSec: 0,
                                                      bedDistanceMm: Int(bedDistMm))
                                } else {
                                    vm.sendDiagnostic(motorId: motor.motorId, controlType: 0x01,
                                                      direction: direction, speedPct: Int(speedPct),
                                                      durationSec: Int(durationSec))
                                }
                            })
                            GradientButton(text: "STOP", action: {
                                vm.sendStopDiagnosis(); vm.clearDiagnosis()
                            })
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                }
            } else {
                Text("Select a motor above")
                    .foregroundColor(.secondary).padding(.top, 20)
                Spacer()
            }
        }
    }

    private func diagRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.semibold)
        }
    }
}
