import SwiftUI

struct FlyerOptionsView: View {
    @ObservedObject var vm: FlyerViewModel
    @State private var gearboxRunning = false
    @State private var showResetConfirm = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Spacer()

                // ── Enable Logging ─────────────────────────────────────────────
                VStack(spacing: 0) {
                    HStack {
                        Text("Enable Logging")
                            .font(.body).foregroundColor(SpinColors.blue)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { vm.logEnabled },
                            set: { vm.sendLog(enabled: $0) }
                        ))
                        .labelsHidden()
                        .tint(SpinColors.lightGreen)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    Divider()
                }

                Spacer()

                // ── Sensor Cut Counts ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    cutCountRow("Front Sensor Cut Count", count: vm.runState.frontCutCount)
                    cutCountRow("Back Sensor Cut Count",  count: vm.runState.backCutCount)
                    GradientButton(text: "Reset Cut Counts", action: { showResetConfirm = true })
                        .padding(.horizontal, 16)
                    Divider().padding(.top, 4)
                }

                Spacer()

                // ── Gear Box Settings ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Text("Gear Box Settings")
                        .font(.body).foregroundColor(SpinColors.blue)
                        .padding(.horizontal, 16)
                    gearboxRow("Left",  value: vm.gearboxLeft)
                    gearboxRow("Right", value: vm.gearboxRight)
                    HStack(spacing: 8) {
                        GradientButton(text: "START", action: {
                            vm.sendGearbox(0x01); gearboxRunning = true
                        }, enabled: !gearboxRunning)
                        GradientButton(text: "STOP", action: {
                            vm.sendGearbox(0x02); gearboxRunning = false
                        }, enabled: gearboxRunning)
                    }
                    .padding(.horizontal, 16)
                    Divider().padding(.top, 4)
                }

                Spacer()

                // ── RTF Settings ───────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Text("RTF Settings")
                        .font(.body).foregroundColor(SpinColors.blue)
                        .padding(.horizontal, 16)
                    HStack(spacing: 12) {
                        Button(action: { vm.sendRead() }) {
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(SpinColors.blue)
                                Text("receive").font(.caption).foregroundColor(SpinColors.blue)
                            }
                        }
                        Button(action: { adjustRtf(by: 0.01) }) {
                            Image(systemName: "plus").foregroundColor(SpinColors.blue)
                        }
                        Text(vm.settings.rtf)
                            .font(.body).fontWeight(.bold)
                            .frame(width: 80, height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1))
                        Button(action: { adjustRtf(by: -0.01) }) {
                            Image(systemName: "minus").foregroundColor(SpinColors.blue)
                        }
                        Button(action: { vm.sendSave() }) {
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.up.circle")
                                    .foregroundColor(SpinColors.blue)
                                Text("send").font(.caption).foregroundColor(SpinColors.blue)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                Spacer()
            }

            if let msg = vm.logMessage {
                SaveBanner(message: msg, success: true)
                    .animation(.easeInOut, value: msg)
            }
        }
        .confirmationDialog("Reset Cut Counts",
                            isPresented: $showResetConfirm,
                            titleVisibility: .visible) {
            Button("Reset", role: .destructive) { vm.sendResetCutCounts() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Reset both Front and Back sensor cut counts to 0?")
        }
    }

    private func cutCountRow(_ label: String, count: Int) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text("\(count)").font(.title3).fontWeight(.bold)
        }
        .padding(.horizontal, 16)
    }

    private func gearboxRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).fontWeight(.bold).frame(width: 50, alignment: .leading)
            Text(value).font(.subheadline).fontWeight(.bold)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 10)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1))
        }
        .padding(.horizontal, 16)
    }

    private func adjustRtf(by delta: Double) {
        let v = (Double(vm.settings.rtf) ?? 1.0) + delta
        vm.settings.rtf = String(format: "%.2f", v)
    }
}
