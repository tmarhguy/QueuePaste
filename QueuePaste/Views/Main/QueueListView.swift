import SwiftUI

struct QueueListView: View {
    @Environment(QueueViewModel.self) var vm

    var body: some View {
        Group {
            if vm.items.isEmpty {
                EmptyStateView()
            } else {
                listContent
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    Section {
                        ForEach(Array(vm.items.enumerated()), id: \.element.id) { index, item in
                            QueueRowView(item: item, index: index, isCurrent: index == vm.pointer)
                                .id(index)
                                .listRowBackground(rowBackground(for: index))
                        }
                    } header: {
                        Text("\(vm.items.count) items · position \(min(vm.pointer + 1, vm.items.count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
                .listStyle(.inset)
                .padding(.top, 4)
                .onChange(of: vm.pointer) { _, newPointer in
                    withAnimation {
                        proxy.scrollTo(newPointer, anchor: .center)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func rowBackground(for index: Int) -> some View {
        Group {
            if index == vm.pointer && (vm.state == .active || vm.state == .paused) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.12))
            } else {
                Color.clear
            }
        }
    }
}

struct QueueRowView: View {
    let item: QueueItem
    let index: Int
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Index badge
            Text("\(index + 1)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
                .frame(minWidth: 28, alignment: .trailing)

            // Current item indicator
            if isCurrent {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .imageScale(.small)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(item.isSkipped ? .orange : .clear)
                    .imageScale(.small)
            }

            // Item text
            Text(item.text)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(item.isSkipped ? .secondary : .primary)
                .strikethrough(item.isSkipped, color: .secondary)
                .lineLimit(1)

            Spacer()

            if item.isSkipped {
                Text("skipped")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.orange.opacity(0.1)))
            }
        }
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.15), value: isCurrent)
    }
}

#Preview {
    let vm = QueueViewModel()
    vm.loadExample()
    vm.start()
    return QueueListView()
        .environment(vm)
        .frame(width: 420, height: 300)
}
