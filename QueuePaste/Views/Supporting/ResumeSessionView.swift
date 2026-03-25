import SwiftUI

struct ResumeSessionView: View {
    @Environment(QueueViewModel.self) var vm

    private static let savedAtFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)

                VStack(spacing: 6) {
                    Text("Resume previous session?")
                        .font(.title3.weight(.semibold))

                    Text("\(vm.pendingResumeItemCount) items · currently at item \(vm.pendingResumeCurrentItemNumber)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let savedAt = vm.pendingResumeSavedAt {
                        Text("Saved \(Self.savedAtFormatter.string(from: savedAt))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                VStack(spacing: 8) {
                    Button {
                        vm.resumeSession()
                    } label: {
                        Text("Resume")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return)

                    Button {
                        vm.startFresh()
                    } label: {
                        Text("Start Fresh")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(role: .destructive) {
                        vm.clearSavedSession()
                    } label: {
                        Text("Clear Saved Session")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .frame(width: 320)
    }
}

#Preview {
    let vm = QueueViewModel()
    vm.pendingRestore = PersistedQueueSession(
        savedAt: Date(),
        items: (0..<12).map { QueueItem(text: "item\($0)") },
        pointer: 4,
        state: .ready,
        skippedItems: [],
        inputText: ""
    )
    return ResumeSessionView()
        .environment(vm)
}
