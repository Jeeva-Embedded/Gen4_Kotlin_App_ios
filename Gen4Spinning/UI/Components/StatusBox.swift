import SwiftUI

struct StatusBox: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline).fontWeight(.bold)
                .foregroundColor(SpinColors.blue)
            Text(value.isEmpty ? "--" : value)
                .font(.body).fontWeight(.bold)
                .foregroundColor(valueColor)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 10)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
        }
    }
}
