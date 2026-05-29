import SwiftUI

struct FlyerSettingsView: View {
    @ObservedObject var vm: FlyerViewModel
    let onNavigatePid: () -> Void

    @State private var showParams    = false
    @State private var validationMsg: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    FieldInput(label: "Spindle Speed (RPM)",   value: $vm.settings.spindleSpeed)
                    FieldInput(label: "Draft",                  value: $vm.settings.draft)
                    FieldInput(label: "Twist Per Inch",         value: $vm.settings.twistPerInch)
                    FieldInput(label: "RTF",                    value: $vm.settings.rtf)
                    FieldInput(label: "Layers",                 value: $vm.settings.layers)
                    FieldInput(label: "Max Height (mm)",        value: $vm.settings.maxHeight)
                    FieldInput(label: "Roving Width (mm)",      value: $vm.settings.rovingWidth)
                    FieldInput(label: "Delta Bobbin Dia (mm)",  value: $vm.settings.deltaBobbinDia)
                    FieldInput(label: "Bare Bobbin Dia (mm)",   value: $vm.settings.bareBobbinDia)
                    FieldInput(label: "Ramp Up Time (s)",       value: $vm.settings.rampUpTime)
                    FieldInput(label: "Ramp Down Time (s)",     value: $vm.settings.rampDownTime)
                    FieldInput(label: "Change Layer Time (ms)", value: $vm.settings.changeLayerTime)
                    FieldInput(label: "Cone Angle Factor",      value: $vm.settings.coneAngleFactor)
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
            FlyerInternalParamsView(settings: vm.settings)
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
        vm.sendSave()
    }

    private func validate(_ s: FlyerSettings) -> String? {
        guard let ss = Int(s.spindleSpeed), (500...1100).contains(ss) else { return "Spindle speed must be 500–1100 RPM." }
        guard let dr = Double(s.draft), (5.0...15.0).contains(dr)     else { return "Draft must be 5–15." }
        guard let tp = Double(s.twistPerInch), (1.0...1.6).contains(tp) else { return "Twist per inch must be 1.0–1.6." }
        guard let rt = Double(s.rtf), (0.5...1.5).contains(rt)        else { return "RTF must be 0.5–1.5." }
        guard let ly = Int(s.layers), (1...100).contains(ly)           else { return "Layers must be 1–100." }
        guard let mh = Int(s.maxHeight), (250...300).contains(mh)     else { return "Max height must be 250–300 mm." }
        guard let rw = Double(s.rovingWidth), (1.0...8.0).contains(rw) else { return "Roving width must be 1–8 mm." }
        guard let dd = Double(s.deltaBobbinDia), (0.3...2.5).contains(dd) else { return "Delta bobbin dia must be 0.3–2.5 mm." }
        guard let bd = Int(s.bareBobbinDia), (46...52).contains(bd)   else { return "Bare bobbin dia must be 46–52 mm." }
        guard let ru = Int(s.rampUpTime), (5...20).contains(ru)       else { return "Ramp up time must be 5–20 s." }
        guard let rd = Int(s.rampDownTime), (5...20).contains(rd)     else { return "Ramp down time must be 5–20 s." }
        guard let cl = Int(s.changeLayerTime), (200...2500).contains(cl) else { return "Change layer time must be 200–2500 ms." }
        guard let ca = Double(s.coneAngleFactor), (0.1...3.0).contains(ca) else { return "Cone angle factor must be 0.1–3." }
        return nil
    }
}

// MARK: - Internal Parameters popup

struct FlyerInternalParamsView: View {
    let settings: FlyerSettings

    var body: some View {
        NavigationView {
            List {
                let d = calc(settings)
                paramRow("Delivery",            d.delivery,       "%.2f m/min")
                paramRow("Stroke Velocity",      d.strokeVel,      "%.2f mm/s",  warnAbove: 5.5)
                paramRow("Max Layers Possible",  d.maxLayers,      "%.0f")
                paramRow("Flyer Motor RPM",      d.flyerRpm,       "%.0f")
                paramRow("Bobbin Motor RPM",     d.bobbinRpm,      "%.0f")
                paramRow("FR Motor RPM",         d.frMotorRpm,     "%.0f")
                paramRow("BR Motor RPM",         d.brMotorRpm,     "%.0f")
                paramRow("Lift Motor RPM",       d.liftMotorRpm,   "%.0f")
            }
            .navigationTitle("Internal Parameters")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func paramRow(_ label: String, _ value: Double?, _ fmt: String, warnAbove: Double = 1450) -> some View {
        let text = value.map { String(format: fmt, $0) } ?? "–"
        let warn = (value ?? 0) > warnAbove
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(text).font(.subheadline).fontWeight(.semibold)
                .foregroundColor(warn ? .red : .primary)
        }
    }

    private struct Params {
        var delivery, strokeVel, maxLayers: Double?
        var flyerRpm, bobbinRpm, frMotorRpm, brMotorRpm, liftMotorRpm: Double?
    }

    private func calc(_ s: FlyerSettings) -> Params {
        guard let ss  = Double(s.spindleSpeed),
              let dr  = Double(s.draft),
              let tp  = Double(s.twistPerInch), tp != 0,
              let mh  = Double(s.maxHeight),
              let rw  = Double(s.rovingWidth),  rw != 0,
              let dd  = Double(s.deltaBobbinDia), dd != 0,
              let bd  = Double(s.bareBobbinDia),
              let ca  = Double(s.coneAngleFactor) else { return Params() }
        let delivery    = (ss / tp) * 0.0254
        let frRpm       = (delivery * 1000.0) / 94.248
        let frMotorRpm  = frRpm * 3.33
        let brMotorRpm  = (frRpm * 22.642) / (dr / 1.5)
        let ml1         = mh / rw
        let ml2         = (140.0 - bd) / dd
        let maxLayers   = min(ml1, ml2) - 5.0
        let deltaRpm    = (delivery * 1000.0) / (bd * .pi)
        let bobbinRpm   = ss + deltaRpm
        let strokeDelta = rw * ca
        let strokeVel   = (deltaRpm * strokeDelta) / 60.0
        let liftMotorRpm = (strokeVel * 60.0 / 4.0) * 9.0
        return Params(delivery: delivery, strokeVel: strokeVel, maxLayers: maxLayers,
                      flyerRpm: ss, bobbinRpm: bobbinRpm, frMotorRpm: frMotorRpm,
                      brMotorRpm: brMotorRpm, liftMotorRpm: liftMotorRpm)
    }
}
