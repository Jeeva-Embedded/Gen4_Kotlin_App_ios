import SwiftUI

struct CardingSettingsView: View {
    @ObservedObject var vm: CardingViewModel
    let onNavigatePid: () -> Void

    @State private var showParams    = false
    @State private var validationMsg: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    FieldInput(label: "Delivery Speed (m/min)", value: $vm.settings.deliverySpeed)
                    FieldInput(label: "Card Feed Ratio",        value: $vm.settings.cardFeedRatio)
                    FieldInput(label: "Length Limit (m)",       value: $vm.settings.lengthLimit)
                    FieldInput(label: "Cylinder Speed (RPM)",   value: $vm.settings.cylSpeed,
                               enabled: vm.settingsChangeAllowed)
                    FieldInput(label: "Beater Speed (RPM)",     value: $vm.settings.btrSpeed,
                               enabled: vm.settingsChangeAllowed)
                    FieldInput(label: "Picker Cyl Speed (RPM)", value: $vm.settings.pickerCylSpeed,
                               enabled: vm.settingsChangeAllowed)
                    FieldInput(label: "Beater Feed",            value: $vm.settings.btrFeed)
                    FieldInput(label: "AF Feed",                value: $vm.settings.afFeed)
                }
                .padding(16)
            }

            if let r = vm.readResult    { SaveBanner(message: r ? "Settings received" : "Settings not received", success: r) }
            if vm.defaultApplied == true { SaveBanner(message: "Defaults received", success: true) }
            if let s = vm.saveResult    { SaveBanner(message: s ? "Settings saved successfully" : "Save failed", success: s) }

            SettingsToolbar(
                onRead:   { vm.sendRead() },
                onAll:    { vm.resetToDefaults() },
                onSave:   { if let e = validate(vm.settings) { validationMsg = e } else { vm.sendSave() } },
                onPid:    onNavigatePid,
                onLimits: { showParams = true }
            )
        }
        .sheet(isPresented: $showParams) { CardingInternalParamsView(settings: vm.settings) }
        .alert("Invalid Settings", isPresented: Binding(get: { validationMsg != nil }, set: { if !$0 { validationMsg = nil } })) {
            Button("OK") { validationMsg = nil }
        } message: { Text(validationMsg ?? "") }
    }

    private func validate(_ s: CardingSettings) -> String? {
        guard let ds = Double(s.deliverySpeed), (2.5...50.0).contains(ds)     else { return "Delivery speed must be 2.5–50 m/min." }
        guard let cf = Double(s.cardFeedRatio), (0.4...20.0).contains(cf)    else { return "Card feed ratio must be 0.4–20." }
        guard let ll = Int(s.lengthLimit),    (100...1000).contains(ll)       else { return "Length limit must be 100–1000 m." }
        guard let cs = Int(s.cylSpeed),       (300...875).contains(cs)        else { return "Cylinder speed must be 300–875 RPM." }
        guard let bs = Int(s.btrSpeed),       (300...650).contains(bs)        else { return "Beater speed must be 300–650 RPM." }
        guard let ps = Int(s.pickerCylSpeed), (300...700).contains(ps)        else { return "Picker cyl speed must be 300–700 RPM." }
        guard let bf = Int(s.btrFeed),        (1...11).contains(bf)           else { return "Beater feed must be 1–11." }
        guard let af = Int(s.afFeed),         (1...8).contains(af)            else { return "AF feed must be 1–8." }
        return nil
    }
}

struct CardingInternalParamsView: View {
    let settings: CardingSettings
    var body: some View {
        NavigationView {
            List {
                let ds = Double(settings.deliverySpeed) ?? 0
                let cf = Double(settings.cardFeedRatio) ?? 0
                let cs = Double(settings.cylSpeed)      ?? 0
                let bs = Double(settings.btrSpeed)      ?? 0
                paramRow("Cylinder Motor RPM", cs / 1.2)
                paramRow("Beater Motor RPM",   bs / 1.2)
                paramRow("Cage Motor RPM",     (ds * 1000.0 / 213.63) * 6.91)
                paramRow("Coiler Motor RPM",   ((ds * 1000.0 * cf) / 194.779) / 1.656 * 6.91)
            }
            .navigationTitle("Internal Parameters").navigationBarTitleDisplayMode(.inline)
        }
    }
    private func paramRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(String(format: "%.0f", value)).font(.subheadline).fontWeight(.semibold)
                .foregroundColor(value > 1450 ? .red : .primary)
        }
    }
}
