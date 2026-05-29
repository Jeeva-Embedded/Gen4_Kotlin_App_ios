import SwiftUI

struct RingOptionsView: View {
    @ObservedObject var vm: RingViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Spacer()
                GradientButton(text: "Reset Grams/Spindle", action: { vm.sendResetGrams() })
                    .padding(.horizontal, 16)
                Spacer()
                Divider()
                HStack {
                    Text("Enable Logging").font(.body).foregroundColor(SpinColors.blue)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { vm.logEnabled },
                        set: { vm.sendLog(enabled: $0) }
                    ))
                    .labelsHidden().tint(SpinColors.lightGreen)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                Divider()
                Spacer()
            }

            if let msg = vm.logMessage {
                SaveBanner(message: msg, success: true).animation(.easeInOut, value: msg)
            }
        }
    }
}
