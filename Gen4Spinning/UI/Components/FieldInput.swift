import SwiftUI

struct FieldInput: View {
    let label: String
    @Binding var value: String
    var enabled: Bool = true
    var keyboardType: UIKeyboardType = .decimalPad

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline).foregroundColor(SpinColors.blue)
            TextField(label, text: $value)
                .keyboardType(keyboardType)
                .disabled(!enabled)
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(enabled ? Color.gray : Color.gray.opacity(0.4), lineWidth: 1))
                .foregroundColor(enabled ? .primary : .secondary)
        }
    }
}
