import SwiftUI

struct DfOptionsView: View {
    @ObservedObject var vm: DfViewModel
    @State private var validationError: String? = nil

    private var isIdle: Bool { vm.runState.substate == 0x00 }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // ── Enable Logging ─────────────────────────────────────────
                    HStack {
                        Text("Enable Logging").font(.body).foregroundColor(SpinColors.blue)
                        Spacer()
                        Toggle("", isOn: Binding(get: { vm.logEnabled }, set: { vm.sendLog(enabled: $0) }))
                            .labelsHidden().tint(SpinColors.lightGreen)
                    }
                    .padding(.horizontal, 16).padding(.top, 12)

                    Divider()

                    // ── Auto Leveller ──────────────────────────────────────────
                    HStack {
                        Text("Auto Leveller").font(.body).foregroundColor(SpinColors.blue)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { vm.alEnabled },
                            set: { guard isIdle else { return }; vm.sendAutoLeveller(enabled: $0) }
                        ))
                        .labelsHidden().tint(SpinColors.lightGreen)
                        .disabled(!isIdle)
                    }
                    .padding(.horizontal, 16)

                    if !isIdle {
                        Text("Go to Idle to change")
                            .font(.caption).foregroundColor(.red)
                            .padding(.horizontal, 16)
                    }

                    Divider()

                    // ── AL Settings ────────────────────────────────────────────
                    Text("AL Settings")
                        .font(.headline).foregroundColor(SpinColors.blue)
                        .padding(.horizontal, 16)

                    Group {
                        FieldInput(label: "KP Gain",              value: $vm.alSettings.kp)
                        FieldInput(label: "Sliver N+1 Threshold", value: $vm.alSettings.sliver6)
                        FieldInput(label: "Sliver N Threshold",   value: $vm.alSettings.sliver5)
                        FieldInput(label: "Sliver N-1 Threshold", value: $vm.alSettings.sliver4)
                        FieldInput(label: "Target g/m",           value: $vm.alSettings.target)
                    }
                    .padding(.horizontal, 16)

                    if let err = validationError {
                        Text(err)
                            .font(.caption).foregroundColor(.red).fontWeight(.medium)
                            .padding(.horizontal, 16)
                    }

                    HStack(spacing: 12) {
                        GradientButton(text: "GET", action: {
                            validationError = nil
                            vm.sendAlGet()
                        })
                        GradientButton(text: "SAVE", action: {
                            let ok = vm.sendAlSave()
                            validationError = ok ? nil :
                                "Check: KP (0 < KP ≤ 1), Sliver N+1 < N < N-1, Target (4 < g/m ≤ 6)"
                        })
                    }
                    .padding(.horizontal, 16)

                    Divider()

                    // ── AL Calibration ─────────────────────────────────────────
                    Text("AL Calibration")
                        .font(.headline).foregroundColor(SpinColors.blue)
                        .padding(.horizontal, 16)

                    Text(calibrationStatusLabel)
                        .font(.subheadline).foregroundColor(.gray)
                        .padding(.horizontal, 16)

                    if vm.calibrationState.status == .collecting {
                        ProgressView()
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding(.horizontal, 16)
                    }

                    if vm.calibrationState.status == .done {
                        VStack(spacing: 4) {
                            Text("\(vm.calibrationState.avgValue)")
                                .font(.system(size: 56, weight: .bold))
                            Text("avg  (\(vm.calibrationState.count) samples)")
                                .font(.caption).foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                    }

                    if vm.calibrationState.status == .collecting {
                        Button("STOP") { vm.sendCalibrationStop() }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                    } else {
                        GradientButton(text: "START", action: { vm.sendCalibrationStart() })
                            .padding(.horizontal, 16)
                    }

                    Divider()

                    // ── Reset Length Counter ───────────────────────────────────
                    GradientButton(text: "Reset Length Counter", action: { vm.sendResetLengthCounter() })
                        .padding(.horizontal, 16)

                    Spacer(minLength: 32)
                }
                .padding(.vertical, 8)
            }

            // ── Banners ────────────────────────────────────────────────────────
            let banner: (String, Bool)? = {
                if let ok = vm.alSaveResult { return (ok ? "AL Settings Saved" : "AL Save Failed", ok) }
                if let ok = vm.alReadResult { return (ok ? "AL Settings Received" : "No Response", ok) }
                if let msg = vm.logMessage   { return (msg, true) }
                if let msg = vm.alMessage    { return (msg, true) }
                return nil
            }()

            if let (msg, success) = banner {
                SaveBanner(message: msg, success: success).animation(.easeInOut, value: msg)
            }
        }
    }

    private var calibrationStatusLabel: String {
        switch vm.calibrationState.status {
        case .idle:       return "Idle"
        case .collecting: return "Collecting..."
        case .done:       return "Done"
        }
    }
}
