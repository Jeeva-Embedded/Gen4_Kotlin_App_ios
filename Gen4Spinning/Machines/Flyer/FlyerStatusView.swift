import SwiftUI

struct FlyerStatusView: View {
    @ObservedObject var vm: FlyerViewModel

    private var substate: UInt8 { vm.runState.substate }
    private var isRunning: Bool { substate == 0x01 }
    private var isPaused:  Bool { substate == 0x02 }
    private var isError:   Bool { substate == 0x03 }
    private var isHoming:  Bool { substate == 0x04 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                StatusBox(label: "Status", value: substateLabel(substate))

                if isRunning {
                    StatusBox(label: "Layer", value: "\(vm.runState.layers)")
                    LiftAnimationView(leftLift: vm.runState.leftLift, rightLift: vm.runState.rightLift)
                    FlyerCarouselView(vm: vm)
                } else if isPaused {
                    StatusBox(label: "Reason For Pause", value: vm.runState.pauseReason)
                    StatusBox(label: "Layers",           value: "\(vm.runState.pauseLayer)")
                } else if isHoming {
                    LiftAnimationView(leftLift: vm.runState.leftLift, rightLift: vm.runState.rightLift)
                } else if isError {
                    StatusBox(label: "Error Information",
                              value: "\(vm.runState.errorInformation) (\(vm.runState.errorCode))")
                    StatusBox(label: "Error Source", value: vm.runState.errorSource)
                    StatusBox(label: "Layers",       value: "\(vm.runState.errorLayer)")
                }
            }
            .padding(16)
        }
    }

    private func substateLabel(_ s: UInt8) -> String {
        switch s {
        case 0x00: return "IDLE"
        case 0x01: return "RUNNING"
        case 0x02: return "PAUSED"
        case 0x03: return "ERROR"
        case 0x04: return "HOMING"
        case 0x05: return "INCHING"
        case 0x06: return "CAN OVER"
        default:   return "UNKNOWN"
        }
    }
}

// MARK: - Lift Animation

struct LiftAnimationView: View {
    let leftLift: Float
    let rightLift: Float

    private var diff: Float { leftLift - rightLift }
    private var angleDeg: Double { Double(diff / 4.0) * (180.0 / 40.0) }

    var body: some View {
        VStack(spacing: 8) {
            Text(String(format: "Δ (mm) = %.2f", diff))
                .font(.subheadline).fontWeight(.bold)
            Text("(Δ = L - R)").font(.caption)

            Rectangle()
                .fill(SpinColors.lightGreen)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .rotationEffect(.degrees(angleDeg))
                .padding(.horizontal, 8)

            HStack {
                VStack {
                    Text("L").font(.title3).fontWeight(.bold)
                    Text(String(format: "%.2f", leftLift)).font(.caption)
                }
                Spacer()
                VStack {
                    Text("R").font(.title3).fontWeight(.bold)
                    Text(String(format: "%.2f", rightLift)).font(.caption)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
