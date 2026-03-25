import SwiftUI

/// Queue transport and session state — lives in the sidebar so the main canvas stays clean.
struct QueueTransportPanel: View {
    @Environment(QueueViewModel.self) var vm

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if vm.state == .active || vm.state == .paused {
                progressBlock
            }

            sessionStateHeader

            compactTransportIcons
                .frame(maxWidth: .infinity, alignment: .leading)

            primaryActions
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary.opacity(0.35))
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    // MARK: - Progress

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: vm.progress)
                .progressViewStyle(.linear)
                .tint(vm.state == .paused ? Color.orange : Color.accentColor)

            if let current = vm.currentItem {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Now")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                    Text(current.text)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private var sessionStateHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(sessionStateColor)
                .frame(width: 8, height: 8)
                .shadow(color: sessionStateColor.opacity(0.35), radius: 2, y: 1)

            Text(vm.state.displayName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            if !vm.items.isEmpty && vm.state != .complete {
                Text("\(vm.pointer + 1) / \(vm.items.count)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.06)))
            }

            Spacer(minLength: 0)
        }
    }

    private var compactTransportIcons: some View {
        HStack(spacing: 4) {
            iconButton(icon: "backward.fill", help: "Previous item", disabled: !vm.canPrev) {
                vm.prev()
            }
            iconButton(icon: "forward.fill", help: "Skip item", disabled: !vm.canSkip) {
                vm.skip()
            }
            iconButton(icon: "arrow.counterclockwise", help: "Reset to start", disabled: !vm.canReset) {
                vm.resetToStart()
            }
            iconButton(
                icon: vm.isHUDVisible ? "rectangle.inset.filled" : "rectangle",
                help: vm.isHUDVisible ? "Hide HUD" : "Show HUD",
                disabled: false
            ) {
                vm.toggleHUD()
            }
        }
    }

    @ViewBuilder
    private var primaryActions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if vm.state == .active || vm.state == .paused {
                    if vm.state == .paused {
                        Button {
                            vm.resume()
                        } label: {
                            Label("Resume", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            vm.pause()
                        } label: {
                            Label("Pause", systemImage: "pause.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button {
                        if vm.state == .complete {
                            vm.resetToStart()
                        } else {
                            vm.start()
                        }
                    } label: {
                        Label(vm.state == .complete ? "Run Again" : "Start", systemImage: vm.state == .complete ? "arrow.clockwise" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.state == .idle)
                }

                Button(role: .destructive) {
                    vm.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(vm.state == .idle || vm.state == .ready || vm.state == .complete)
            }
            .controlSize(.regular)

            Button {
                vm.pasteNext()
            } label: {
                HStack {
                    Label("Paste Next", systemImage: "doc.on.clipboard.fill")
                    Spacer()
                    Text(vm.pasteHotkeyLabel)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.08)))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(vm.state != .active)
        }
    }

    private func iconButton(
        icon: String,
        help: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 28, height: 26)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .help(help)
    }

    private var sessionStateColor: Color {
        switch vm.state {
        case .idle:     return .gray
        case .ready:    return .blue
        case .active:   return .green
        case .paused:   return .orange
        case .complete: return .blue
        }
    }
}

/// Shown when no queue is loaded yet.
struct SidebarQueuePlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Session")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Load items in Prepare, then start the queue from here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary.opacity(0.25))
        }
    }
}

#Preview("Transport") {
    let vm = QueueViewModel()
    vm.loadExample()
    vm.start()
    return QueueTransportPanel()
        .environment(vm)
        .frame(width: 260)
        .padding()
}
