import SwiftUI

struct SaveBanner: View {
    let message: String
    let success: Bool

    var body: some View {
        Text(message)
            .font(.subheadline).fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(success ? SpinColors.successBg : SpinColors.errorBg)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
