import SwiftUI

struct CardingOptionsView: View {
    @ObservedObject var vm: CardingViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Spacer()
                // Enable Logging
                VStack(spacing: 0) {
                    HStack {
                        Text("Enable Logging").font(.body).foregroundColor(SpinColors.blue)
                        Spacer()
                        Toggle("", isOn: Binding(get: { vm.logEnabled }, set: { vm.sendLog(enabled: $0) }))
                            .labelsHidden().tint(SpinColors.lightGreen)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    Divider()
                }
                Spacer()
                // Reset Length Counter
                GradientButton(text: "Reset Length Counter", action: { vm.sendResetLengthCounter() })
                    .padding(.horizontal, 16)
                Spacer()
            }

            if let msg = vm.logMessage {
                SaveBanner(message: msg, success: true).animation(.easeInOut, value: msg)
            }
        }
    }
}
