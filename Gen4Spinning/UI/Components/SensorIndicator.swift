import SwiftUI

struct SensorIndicator: View {
    let label: String
    let active: Bool

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(active ? SpinColors.lightGreen : Color.gray.opacity(0.4))
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(Color.gray, lineWidth: 1))
            Text(label)
                .font(.caption).multilineTextAlignment(.center)
                .foregroundColor(SpinColors.blue)
        }
    }
}

struct SettingsToolbar: View {
    let onRead:   () -> Void
    let onAll:    () -> Void
    let onSave:   () -> Void
    let onPid:    () -> Void
    let onLimits: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            toolbarBtn("Read",    action: onRead)
            toolbarBtn("Default", action: onAll)
            toolbarBtn("Save",    action: onSave)
            toolbarBtn("PID",     action: onPid)
            toolbarBtn("Limits",  action: onLimits)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func toolbarBtn(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(SpinColors.blue)
                .cornerRadius(6)
        }
    }
}
