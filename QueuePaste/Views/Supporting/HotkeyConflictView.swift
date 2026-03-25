import SwiftUI

struct HotkeyConflictView: View {
    @Environment(QueueViewModel.self) var vm

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Hotkey conflict")
                    .font(.caption.weight(.semibold))

                Text("⌥Space is unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Dismiss") {
                vm.showHotkeyConflict = false
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

#Preview {
    let vm = QueueViewModel()
    vm.showHotkeyConflict = true
    return HotkeyConflictView()
        .environment(vm)
        .frame(width: 400)
        .padding(.vertical)
}
