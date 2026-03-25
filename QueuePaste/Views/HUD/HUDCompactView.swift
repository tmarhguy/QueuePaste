import SwiftUI

/// Single HUD surface: compact by default, expands in place for tools and skipped list.
struct HUDPanelContent: View {
    @Environment(QueueViewModel.self) var vm
    @State private var skippedExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.bottom, 14)

            progressMetricsRow
                .padding(.bottom, 10)

            progressCapsule
                .padding(.bottom, 14)

            currentItemSurface

            if vm.hudExpanded {
                expandedChrome
                    .padding(.top, 16)
            }
        }
        .padding(18)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: vm.hudExpanded)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            BrandMarkImage(length: 34, cornerRadius: 10)
                .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text("QueuePaste")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(headerSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            statusPill

            expandToggle

            hudCloseButton
        }
    }

    private var hudCloseButton: some View {
        Button {
            NotificationCenter.default.post(name: .queuePasteHUDDismissRequested, object: nil)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background {
                    Circle()
                        .fill(Color.primary.opacity(0.04))
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Hide HUD")
    }

    private var headerSubtitle: String {
        switch vm.state {
        case .active:
            return "Paste in the frontmost app with your hotkey."
        case .paused:
            return "Paused — resume when ready."
        case .ready:
            return "Start the queue, then switch apps."
        case .complete:
            return "Queue finished."
        case .idle:
            return "Load items in the main window."
        }
    }

    private var statusPill: some View {
        Text(statusPillTitle)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(statusPillForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule(style: .continuous)
                    .fill(statusPillBackground)
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(statusPillStroke, lineWidth: 0.5)
            }
    }

    private var statusPillTitle: String {
        switch vm.state {
        case .idle:     return "Idle"
        case .ready:    return "Ready"
        case .active:   return "Live"
        case .paused:   return "Paused"
        case .complete: return "Done"
        }
    }

    private var statusPillForeground: Color {
        switch vm.state {
        case .active:   return .black
        case .paused:   return .orange
        case .complete: return .purple
        case .ready:    return Color.accentColor
        default:        return .secondary
        }
    }

    private var statusPillBackground: Color {
        switch vm.state {
        case .active:   return Color.green.opacity(0.14)
        case .paused:   return Color.orange.opacity(0.14)
        case .complete: return Color.purple.opacity(0.14)
        case .ready:    return Color.accentColor.opacity(0.12)
        default:        return Color.primary.opacity(0.06)
        }
    }

    private var statusPillStroke: Color {
        statusPillForeground.opacity(0.22)
    }

    private var expandToggle: some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                vm.toggleHUDExpanded()
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background {
                    Circle()
                        .fill(Color.primary.opacity(0.04))
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                }
                .rotationEffect(.degrees(vm.hudExpanded ? 180 : 0))
        }
        .buttonStyle(.plain)
        .help(vm.hudExpanded ? "Show less" : "More controls")
    }

    // MARK: - Progress

    private var progressMetricsRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(vm.items.isEmpty ? "—" : "\(vm.pointer + 1)")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(vm.items.isEmpty ? Color.secondary.opacity(0.45) : .primary)
                .contentTransition(.numericText())

            Text("/")
                .font(.title2.weight(.regular))
                .foregroundStyle(.tertiary)

            Text(vm.items.isEmpty ? "—" : "\(vm.items.count)")
                .font(.system(.title2, design: .rounded).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            Spacer(minLength: 0)
        }
    }

    private var progressCapsule: some View {
        GeometryReader { geo in
            let width = vm.items.isEmpty ? 0 : max(6, geo.size.width * CGFloat(vm.progress))
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [progressTint, progressTint.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width)
                    .animation(.easeInOut(duration: 0.28), value: vm.progress)
            }
        }
        .frame(height: 7)
    }

    private var progressTint: Color {
        switch vm.state {
        case .paused:   return .orange
        case .complete: return .purple
        default:        return Color.accentColor
        }
    }

    // MARK: - Current item

    private var currentItemSurface: some View {
        Group {
            if let current = vm.currentItem {
                Text(current.text)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.88)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(placeholderLine)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.028))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        }
    }

    private var placeholderLine: String {
        switch vm.state {
        case .complete:
            return "All items processed."
        case .ready:
            return "Press Start, then use the hotkey to paste."
        default:
            return "No item at pointer — load a queue first."
        }
    }

    // MARK: - Expanded

    private var expandedChrome: some View {
        VStack(alignment: .leading, spacing: 14) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                    Color.primary.opacity(0),
                    Color.primary.opacity(0.09),
                    Color.primary.opacity(0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            if let next = vm.nextItem {
                upNextCard(text: next.text)
            }

            actionStrip

            if !vm.skippedItems.isEmpty {
                skippedDisclosure
            }
        }
    }

    private func upNextCard(text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.turn.down.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor.opacity(0.85))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text("Up next")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                Text(text)
                    .font(.caption.weight(.medium))
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.045))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.09), lineWidth: 0.5)
        }
    }

    private var actionStrip: some View {
        HStack(spacing: 8) {
            HUDActionTile(
                systemImage: "backward.fill",
                title: "Back",
                action: { vm.prev() },
                disabled: !vm.canPrev
            )
            HUDActionTile(
                systemImage: "forward.fill",
                title: "Skip",
                action: { vm.skip() },
                disabled: !vm.canSkip
            )

            if vm.canPause {
                HUDActionTile(
                    systemImage: "pause.fill",
                    title: "Pause",
                    action: { vm.pause() },
                    disabled: false
                )
            } else if vm.canResume {
                HUDActionTile(
                    systemImage: "play.fill",
                    title: "Resume",
                    action: { vm.resume() },
                    disabled: false
                )
            } else {
                HUDActionTile(
                    systemImage: "pause.fill",
                    title: "Pause",
                    action: {},
                    disabled: true
                )
            }
        }
    }

    private var skippedDisclosure: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                    skippedExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.turn.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("Skipped (\(vm.skippedItems.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: skippedExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if skippedExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(vm.skippedItems) { item in
                        Text(item.text)
                            .font(.caption2)
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.leading, 6)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.14), lineWidth: 0.5)
        }
    }
}

// MARK: - Action tile

private struct HUDActionTile: View {
    let systemImage: String
    let title: String
    let action: () -> Void
    var disabled: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(disabled ? 0.03 : 0.048))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(disabled ? 0.03 : 0.07), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.38 : 1)
    }
}

#Preview("HUD — active") {
    let vm = QueueViewModel()
    vm.loadExample()
    vm.start()
    return HUDPanelContent()
        .environment(vm)
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding()
}

#Preview("HUD — expanded") {
    let vm = QueueViewModel()
    vm.loadExample()
    vm.start()
    vm.hudExpanded = true
    vm.skip()
    return HUDPanelContent()
        .environment(vm)
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding()
}
