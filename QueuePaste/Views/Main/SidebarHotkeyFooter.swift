import SwiftUI

struct SidebarHotkeyFooter: View {
    @Environment(QueueViewModel.self) var vm

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Global shortcuts")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HotkeyRow(label: "Paste next", key: vm.pasteHotkeyLabel)
            HotkeyRow(label: "Pause / resume", key: vm.pauseHotkeyLabel)
            HotkeyRow(label: "HUD", key: vm.hudHotkeyLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct HotkeyRow: View {
    let label: String
    let key: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(key)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                )
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SidebarHotkeyFooter()
        .environment(QueueViewModel())
        .frame(width: 260)
        .padding()
}
