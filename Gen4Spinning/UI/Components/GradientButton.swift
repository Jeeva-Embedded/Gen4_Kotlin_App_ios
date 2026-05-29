import SwiftUI

struct GradientButton: View {
    let text: String
    let action: () -> Void
    var enabled: Bool = true

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    enabled
                    ? LinearGradient(colors: [SpinColors.blue, SpinColors.lightGreen],
                                     startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.gray, Color.gray],
                                     startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(8)
        }
        .disabled(!enabled)
    }
}
