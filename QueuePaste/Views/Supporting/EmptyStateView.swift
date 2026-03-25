import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 52))
                .foregroundStyle(.quaternary)
                .symbolEffect(.pulse)

            Text("No queue loaded")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Open Prepare, paste one item per line,\nthen load the queue.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    EmptyStateView()
        .frame(width: 360, height: 260)
}
