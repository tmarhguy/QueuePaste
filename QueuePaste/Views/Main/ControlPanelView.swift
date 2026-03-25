import SwiftUI

/// Preview-only composition of sidebar session + hotkeys (transport lives in `QueueTransportPanel`).
struct ControlPanelView: View {
    var body: some View {
        VStack(spacing: 0) {
            QueueTransportPanel()
            Divider()
            SidebarHotkeyFooter()
        }
    }
}

#Preview("Session + hotkeys") {
    let vm = QueueViewModel()
    vm.loadExample()
    vm.start()
    return ControlPanelView()
        .environment(vm)
        .frame(width: 280)
}
