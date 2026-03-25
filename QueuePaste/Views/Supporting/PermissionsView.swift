import SwiftUI
import AppKit

struct PermissionsView: View {
    @Environment(QueueViewModel.self) var vm
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    permissionHeaderIcon
                    permissionHeaderText
                }
                VStack(alignment: .leading, spacing: 12) {
                    permissionHeaderIcon
                    permissionHeaderText
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                PermissionStep(
                    number: "1",
                    text: "Open System Settings → Privacy & Security → Accessibility"
                )
                PermissionStep(
                    number: "2",
                    text: "Find QueuePaste in the list and enable it"
                )
                PermissionStep(
                    number: "3",
                    text: "Return here and your next paste will succeed"
                )
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    openSettingsButton
                    tryAgainButton
                }
                VStack(alignment: .leading, spacing: 10) {
                    openSettingsButton
                        .frame(maxWidth: .infinity, alignment: .leading)
                    tryAgainButton
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Text("QueuePaste has no account, no cloud sync, and no telemetry. Your queue is saved on disk in Application Support for resume after quit; nothing is uploaded.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private var permissionHeaderIcon: some View {
        Image(systemName: "lock.shield.fill")
            .font(.system(size: 32))
            .foregroundStyle(Color.accentColor)
    }

    private var permissionHeaderText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Accessibility Access Required")
                .font(.headline)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Text("QueuePaste needs permission to paste into other apps.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
    }

    private var openSettingsButton: some View {
        Button("Open System Settings") {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        .buttonStyle(.borderedProminent)
    }

    private var tryAgainButton: some View {
        Button("Try Again") {
            if AccessibilityService.isTrusted() {
                vm.showPermissionsSheet = false
            } else {
                AccessibilityService.promptForTrust()
            }
        }
        .buttonStyle(.bordered)
    }
}

private struct PermissionStep: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    PermissionsView()
        .environment(QueueViewModel())
        .padding()
}
