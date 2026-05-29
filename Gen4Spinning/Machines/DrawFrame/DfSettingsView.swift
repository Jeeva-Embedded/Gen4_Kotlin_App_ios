import SwiftUI

struct DfSettingsView: View {
    @ObservedObject var vm: DfViewModel
    let onNavigatePid: () -> Void

    @State private var showParams    = false
    @State private var validationMsg: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    FieldInput(label: "Delivery Speed (m/min)", value: $vm.settings.deliverySpeed)
                    FieldInput(label: "Draft",                   value: $vm.settings.draft)
                    FieldInput(label: "Length Limit (m)",        value: $vm.settings.lengthLimit)
                    FieldInput(label: "Ramp Up Time (s)",        value: $vm.settings.rampUpTime)
                    FieldInput(label: "Ramp Down Time (s)",      value: $vm.settings.rampDownTime)
                    FieldInput(label: "Creel Tension Factor",    value: $vm.settings.creelTensionFactor)
                }
                .padding(16)
            }

            banners

            SettingsToolbar(
                onRead:   { vm.sendRead() },
                onAll:    { vm.resetToDefaults() },
                onSave:   { handleSave() },
                onPid:    onNavigatePid,
                onLimits: { showParams = true }
            )
        }
        .sheet(isPresented: $showParams) {
            DfInternalParamsView(settings: vm.settings)
        }
        .alert("Invalid Settings", isPresented: Binding(
            get: { validationMsg != nil },
            set: { if !$0 { validationMsg = nil } }
        )) {
            Button("OK") { validationMsg = nil }
        } message: {
            Text(validationMsg ?? "")
        }
    }

    @ViewBuilder private var banners: some View {
        if let r = vm.readResult {
            SaveBanner(message: r ? "Settings received" : "Settings not received", success: r)
        }
        if vm.defaultApplied == true {
            SaveBanner(message: "Defaults received", success: true)
        }
        if let s = vm.saveResult {
            SaveBanner(message: s ? "Settings saved successfully" : "Save failed", success: s)
        }
    }

    private func handleSave() {
        if let err = validate(vm.settings) { validationMsg = err; return }
        let ds = Double(vm.settings.deliverySpeed) ?? 0
        let dr = Double(vm.settings.draft) ?? 1
        let frMotorRpm = ds * 1000.0 / 125.6 * 0.5
        let brMotorRpm = dr > 0 ? (ds * 1000.0 / dr) / 94.2 * 3.07 : 0
        let maxRpm = max(frMotorRpm, brMotorRpm)
        if maxRpm > 1450 {
            validationMsg = "Motor RPM (\(Int(maxRpm))) exceeds 1450. Reduce delivery speed or increase draft."
            return
        }
        vm.sendSave()
    }

    private func validate(_ s: DfSettings) -> String? {
        guard let ds = Int(s.deliverySpeed),    (50...300).contains(ds)        else { return "Delivery speed must be 50–300 m/min." }
        guard let dr = Double(s.draft),         (3.0...12.0).contains(dr)      else { return "Draft must be 3–12." }
        guard let ll = Int(s.lengthLimit),      (5...1250).contains(ll)         else { return "Length limit must be 5–1250 m." }
        guard let ru = Int(s.rampUpTime),       (3...15).contains(ru)           else { return "Ramp up time must be 3–15 s." }
        guard let rd = Int(s.rampDownTime),     (3...15).contains(rd)           else { return "Ramp down time must be 3–15 s." }
        guard let ct = Double(s.creelTensionFactor), (0.25...5.0).contains(ct) else { return "Creel tension factor must be 0.25–5." }
        return nil
    }
}

// MARK: - Internal Parameters sheet

struct DfInternalParamsView: View {
    let settings: DfSettings

    var body: some View {
        NavigationView {
            List {
                let ds = Double(settings.deliverySpeed) ?? 0
                let dr = Double(settings.draft) ?? 1
                let frRpm      = ds * 1000.0 / 125.6
                let frMotorRpm = frRpm * 0.5
                let brRpm      = dr > 0 ? (ds * 1000.0 / dr) / 94.2 : 0
                let brMotorRpm = brRpm * 3.07
                paramRow("FR Roller RPM",  frRpm)
                paramRow("FR Motor RPM",   frMotorRpm)
                paramRow("BR Roller RPM",  brRpm)
                paramRow("BR Motor RPM",   brMotorRpm)
            }
            .navigationTitle("Internal Parameters")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func paramRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(String(format: "%.1f", value)).font(.subheadline).fontWeight(.semibold)
                .foregroundColor(value > 1450 ? .red : .primary)
        }
    }
}
