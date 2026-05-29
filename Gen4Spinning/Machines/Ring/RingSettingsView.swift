import SwiftUI

struct RingSettingsView: View {
    @ObservedObject var vm: RingViewModel
    let onNavigatePid: () -> Void

    @State private var showParams    = false
    @State private var validationMsg: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    FieldInput(label: "Input Yarn (count)",             value: Binding(
                        get: { vm.settings.inputYarn },
                        set: { vm.updateSettings(withInputYarn($0)) }))
                    FieldInput(label: "Output Yarn Dia (mm, blank=auto)", value: $vm.settings.outputYarnDia)
                    FieldInput(label: "Spindle Speed (RPM)",            value: $vm.settings.spindleSpeed)
                    FieldInput(label: "Twist Per Inch",                 value: $vm.settings.twistPerInch)
                    FieldInput(label: "Package Height (mm)",            value: $vm.settings.packageHeight)
                    FieldInput(label: "Dia Build Factor",               value: $vm.settings.diaBuildFactor)
                    FieldInput(label: "Winding Closeness (%)",          value: $vm.settings.windingCloseness)
                    FieldInput(label: "Winding Offset Coils",           value: $vm.settings.windingOffsetCoils)
                }
                .padding(16)
            }

            banners

            SettingsToolbar(
                onRead:   { vm.sendRead() },
                onAll:    {},
                onSave:   { handleSave() },
                onPid:    onNavigatePid,
                onLimits: { showParams = true }
            )
        }
        .sheet(isPresented: $showParams) {
            RingInternalParamsView(settings: vm.settings)
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
        if let s = vm.saveResult {
            SaveBanner(message: s ? "Settings saved successfully" : "Save failed", success: s)
        }
    }

    private func handleSave() {
        if let err = validate(vm.settings) { validationMsg = err; return }
        vm.sendSave()
    }

    private func withInputYarn(_ v: String) -> RingSettings {
        var s = vm.settings; s.inputYarn = v
        if let iv = Int(v) { s.outputYarnDia = String(format: "%.3f", RingProtocol.calcOutputYarnDia(iv)) }
        return s
    }

    private func validate(_ s: RingSettings) -> String? {
        guard let iy = Int(s.inputYarn),  (10...80).contains(iy)          else { return "Input yarn must be 10–80." }
        if !s.outputYarnDia.isEmpty {
            guard let od = Float(s.outputYarnDia), (0.05...1.5).contains(od) else { return "Output yarn dia must be 0.05–1.5 mm." }
        }
        guard let ss  = Int(s.spindleSpeed),  (6000...12000).contains(ss)   else { return "Spindle speed must be 6000–12000 RPM." }
        guard let tpi = Int(s.twistPerInch),  (12...30).contains(tpi)        else { return "Twist per inch must be 12–30." }
        guard let ph  = Int(s.packageHeight), (50...250).contains(ph)        else { return "Package height must be 50–250 mm." }
        guard let dbf = Float(s.diaBuildFactor), (0.05...2.5).contains(dbf) else { return "Dia build factor must be 0.05–2.5." }
        guard let wc  = Int(s.windingCloseness), (50...200).contains(wc)     else { return "Winding closeness must be 50–200%." }
        guard let woc = Int(s.windingOffsetCoils), (1...5).contains(woc)     else { return "Winding offset coils must be 1–5." }
        return nil
    }
}

// MARK: - Internal Parameters sheet

struct RingInternalParamsView: View {
    let settings: RingSettings

    var body: some View {
        NavigationView {
            List {
                let p = calc(settings)
                paramRow("Delivery",            p.delivery,         "%.2f m/min")
                paramRow("Calender Motor RPM",  p.calMotorRpm,      "%.1f")
                paramRow("Output Count (Nm)",   p.outputCountNm,    "%.2f")
                paramRow("Winding Velocity",    p.windingVel,       "%.2f mm/s")
                paramRow("Binding Velocity",    p.bindingVel,       "%.2f mm/s")
                paramRow("Winding Time",        p.windingTime,      "%.1f sec")
                paramRow("Binding Time",        p.bindingTime,      "%.1f sec")
                paramRow("Lift Motor RPM (Binding)", p.liftMotorRpm, "%.0f")
                paramRow("Ht Diff Per Stroke",  p.htDiffPerStroke,  "%.2f mm")
                paramRow("Strokes Per Doff",    p.strokesPerDoff,   "%.0f")
                paramRow("Max Strokes Per Z",   p.maxStrokesPerZ,   "%.0f")
                paramRow("Est Full Bobbin Width", p.estBobbinWidth, "%.2f")
                paramRow("Doff Time",           p.doffTime,         "%.2f min")
                paramRow("Total Yarn Length",   p.totalYarnLength,  "%.2f m")
                paramRow("Total Yarn Weight",   p.totalYarnWeight,  "%.2f g")
            }
            .navigationTitle("Internal Parameters")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func paramRow(_ label: String, _ value: Double?, _ fmt: String) -> some View {
        let text = value.map { String(format: fmt, $0) } ?? "–"
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(text).font(.subheadline).fontWeight(.semibold)
        }
    }

    private struct Params {
        var delivery, calMotorRpm, outputCountNm: Double?
        var windingVel, bindingVel, windingTime, bindingTime, liftMotorRpm: Double?
        var htDiffPerStroke, strokesPerDoff, maxStrokesPerZ, estBobbinWidth: Double?
        var doffTime, totalYarnLength, totalYarnWeight: Double?
    }

    private func calc(_ s: RingSettings) -> Params {
        guard let iy  = Double(s.inputYarn),
              let ss  = Double(s.spindleSpeed),
              let tpi = Double(s.twistPerInch), tpi != 0 else { return Params() }

        let eff_od: Double
        if s.outputYarnDia.isEmpty, let iv = Int(s.inputYarn) {
            eff_od = Double(RingProtocol.calcOutputYarnDia(iv))
        } else if let od = Double(s.outputYarnDia) {
            eff_od = od
        } else { return Params() }

        guard let ph  = Double(s.packageHeight),
              let dbf = Double(s.diaBuildFactor), dbf != 0,
              let wc  = Double(s.windingCloseness),
              let woc = Double(s.windingOffsetCoils) else { return Params() }

        let delivery     = (ss / tpi) * 0.0254
        let calMotorRpm  = (delivery * 1000.0 / 141.37) * 6.91
        let outputCountNm = (iy / 2.0) / 0.591
        let chaseLength  = 55.0
        let emptyBobbinCirc = 24.0 * Double.pi
        let windingVel   = ((delivery * 1000.0 / emptyBobbinCirc) * eff_od * (wc / 100.0)) / 60.0
        let bindingVel   = windingVel * 2.0
        let windingTime  = windingVel > 0 ? chaseLength / windingVel : nil
        let bindingTime  = bindingVel > 0 ? chaseLength / bindingVel : nil
        let liftMotorRpm = (windingVel * 60.0 / 4.0) * 24.0 * 2.0
        let htDiffStroke = woc * (wc / 100.0) * eff_od / dbf
        let strokesPerDoff = htDiffStroke > 0 ? (ph - chaseLength) / htDiffStroke : nil
        let maxStrokesPerZ = htDiffStroke > 0 ? chaseLength / htDiffStroke : nil
        let estBobbinWidth = maxStrokesPerZ.map { $0 * (eff_od * 2.0) + 24.0 }
        let doffTime: Double?
        if let wt = windingTime, let bt = bindingTime, let spd = strokesPerDoff {
            doffTime = spd * (wt + bt) / 60.0
        } else { doffTime = nil }
        let totalYarnLength = doffTime.map { $0 * delivery }
        let totalYarnWeight = totalYarnLength.flatMap { outputCountNm > 0 ? $0 / outputCountNm : nil }

        return Params(delivery: delivery, calMotorRpm: calMotorRpm, outputCountNm: outputCountNm,
                      windingVel: windingVel, bindingVel: bindingVel, windingTime: windingTime,
                      bindingTime: bindingTime, liftMotorRpm: liftMotorRpm,
                      htDiffPerStroke: htDiffStroke, strokesPerDoff: strokesPerDoff,
                      maxStrokesPerZ: maxStrokesPerZ, estBobbinWidth: estBobbinWidth,
                      doffTime: doffTime, totalYarnLength: totalYarnLength, totalYarnWeight: totalYarnWeight)
    }
}
