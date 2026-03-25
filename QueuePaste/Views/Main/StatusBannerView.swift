import SwiftUI

struct StatusBannerView: View {
    @Environment(QueueViewModel.self) var vm

    var body: some View {
        VStack(spacing: 0) {
            // Status message
            if !vm.statusMessage.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)
                        .imageScale(.small)
                    Text(vm.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.05))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Error message
            if !vm.errorMessage.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .imageScale(.small)
                    Text(vm.errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Button("Dismiss") {
                        vm.errorMessage = ""
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.06))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Completion banner
            if vm.showCompletionBanner {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                    Text(vm.statusMessage.isEmpty ? "Queue complete!" : vm.statusMessage)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Button("Clear") {
                        vm.clearQueue()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.08))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.state)
        .animation(.easeInOut(duration: 0.2), value: vm.statusMessage)
        .animation(.easeInOut(duration: 0.2), value: vm.errorMessage)
        .animation(.easeInOut(duration: 0.2), value: vm.showCompletionBanner)
    }

    private var statusIcon: String {
        switch vm.state {
        case .ready:    return "checkmark.circle"
        case .paused:   return "pause.circle"
        case .complete: return "checkmark.seal.fill"
        default:        return "info.circle"
        }
    }

    private var statusColor: Color {
        switch vm.state {
        case .ready:    return .blue
        case .active:   return .green
        case .paused:   return .orange
        case .complete: return .blue
        default:        return .secondary
        }
    }
}

#Preview {
    let vm = QueueViewModel()
    vm.loadExample()
    vm.start()
    vm.statusMessage = "Queue started"
    return StatusBannerView()
        .environment(vm)
        .frame(width: 480)
}
