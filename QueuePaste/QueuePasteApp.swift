import SwiftUI
import AppKit

@main
struct QueuePasteApp: App {
    @State private var vm = QueueViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(vm)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 750)
        .commands {
            // File menu
            CommandGroup(after: .newItem) {
                Button("Import CSV…") {
                    // Stub: trigger file importer
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            // Queue menu
            CommandMenu("Queue") {
                Button("Start Queue") { vm.start() }
                    .disabled(!vm.canStart)

                Button(vm.state == .paused ? "Resume" : "Pause") {
                    if vm.state == .paused { vm.resume() } else { vm.pause() }
                }
                .disabled(vm.state != .active && vm.state != .paused)
                .keyboardShortcut("p", modifiers: [.option, .command])

                Divider()

                Button("Paste Next") { vm.pasteNext() }
                    .disabled(vm.state != .active)
                    .keyboardShortcut(.space, modifiers: [.option])

                Button("Skip Current") { vm.skip() }
                    .disabled(!vm.canSkip)

                Button("Go Back") { vm.prev() }
                    .disabled(!vm.canPrev)

                Divider()

                Button("Reset to Start") { vm.resetToStart() }
                    .disabled(!vm.canReset)

                Button("Clear Queue") { vm.clearQueue() }
            }

            // View menu extras
            CommandGroup(after: .toolbar) {
                Button(vm.isHUDVisible ? "Hide HUD" : "Show HUD") { vm.toggleHUD() }
                    .keyboardShortcut("h", modifiers: [.option, .command])

                Button(vm.hudExpanded ? "Compact HUD" : "Expand HUD") { vm.toggleHUDExpanded() }
                    .disabled(!vm.isHUDVisible)
            }
        }

        // Menu bar extra — asset must be constrained; template `image:` uses intrinsic size and can overflow the bar.
        MenuBarExtra {
            MenuBarView()
                .environment(vm)
        } label: {
            Image(systemName: "list.bullet.rectangle.portrait.fill")
                .accessibilityLabel("QueuePaste")
        }
        .menuBarExtraStyle(.menu)
    }
}

// MARK: - Menu bar dropdown

struct MenuBarView: View {
    @Environment(QueueViewModel.self) var vm

    var body: some View {
        if vm.items.isEmpty {
            Text("No queue loaded")
                .foregroundStyle(.secondary)
        } else {
            Text("Item \(vm.pointer + 1) of \(vm.items.count)")
            if let current = vm.currentItem {
                Text(current.text)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            Divider()
        }

        Button(vm.state == .paused ? "Resume" : "Pause") {
            if vm.state == .paused { vm.resume() } else { vm.pause() }
        }
        .disabled(vm.state != .active && vm.state != .paused)

        Button("Paste Next (⌥Space)") { vm.pasteNext() }
            .disabled(vm.state != .active)

        Divider()

        Button(vm.isHUDVisible ? "Hide HUD" : "Show HUD") { vm.toggleHUD() }

        Divider()

        Button("Open QueuePaste") {
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Quit") { NSApp.terminate(nil) }
    }
}
