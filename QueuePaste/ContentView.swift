
import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(QueueViewModel.self) var vm

    @State private var selectedTab: SidebarTab = .load
    @State private var splitColumnVisibility: NavigationSplitViewVisibility = .all

    private static let windowMinWidth: CGFloat = 800
    private static let windowMinHeight: CGFloat = 600
    /// Below this width the sidebar auto-hides (hysteresis with expandBreakpoint).
    private static let splitCollapseWidth: CGFloat = 720
    private static let splitExpandWidth: CGFloat = 760
    private static let detailContentMaxWidth: CGFloat = 560

    var body: some View {
        @Bindable var vm = vm
        NavigationSplitView(columnVisibility: $splitColumnVisibility) {
            sidebarColumn
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: Self.windowMinWidth, idealWidth: 900, minHeight: Self.windowMinHeight, idealHeight: 600)
        .background(GeometryReader { geo in
            Color.clear
                .onAppear {
                    updateSplitVisibility(for: geo.size.width)
                }
                .onChange(of: geo.size.width) { _, newWidth in
                    updateSplitVisibility(for: newWidth)
                }
        })
        .background(HUDWindowBridge())
        .sheet(isPresented: $vm.showResumePrompt) {
            ResumeSessionView()
        }
        .sheet(isPresented: $vm.showPermissionsSheet) {
            PermissionsView()
        }
        .onAppear {
            vm.checkForSavedSession()
        }
    }

    private func updateSplitVisibility(for width: CGFloat) {
        if width < Self.splitCollapseWidth, splitColumnVisibility != .detailOnly {
            splitColumnVisibility = .detailOnly
        } else if width >= Self.splitExpandWidth, splitColumnVisibility == .detailOnly {
            splitColumnVisibility = .all
        }
    }

    // MARK: - Sidebar

    private var sidebarColumn: some View {
        List(selection: $selectedTab) {
            Section {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Label(tab.sidebarTitle, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            
            if vm.items.isEmpty, vm.state == .idle {
                SidebarQueuePlaceholder()
                    .listRowInsets(EdgeInsets(top: 16, leading: 12, bottom: 20, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            appHeader
                .padding(.horizontal, 12)
                .padding(.top, 28)
                .padding(.bottom, 8)
                .padding(.leading, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(sidebarChromeBackground)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarFooter
                .background(sidebarChromeBackground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationSplitViewColumnWidth(min: 196, ideal: 248, max: 320)
    }

    private var sidebarChromeBackground: some View {
        Color(nsColor: .windowBackgroundColor)
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !vm.items.isEmpty || vm.state != .idle {
                QueueTransportPanel()
            }
            SidebarHotkeyFooter()
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Detail

    private var detailColumn: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StatusBannerView()

                if vm.showHotkeyConflict {
                    HotkeyConflictView()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                }

                detailBody
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle(selectedTab.detailNavigationTitle)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if vm.canStart {
                        Button {
                            vm.start()
                        } label: {
                            Label("Start Queue", systemImage: "play.fill")
                        }
                        .help("Begin pasting items in order")
                    } else if vm.state == .active {
                        Button {
                            vm.pasteNext()
                        } label: {
                            Label("Paste Next", systemImage: "doc.on.clipboard")
                        }
                        .help("Advance to the next item (\(vm.pasteHotkeyLabel))")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailBody: some View {
        switch selectedTab {
        case .load:
            LoadQueueView()
        case .queue:
            QueueListView()
        case .permissions:
            ScrollView {
                PermissionsView()
                    .frame(maxWidth: Self.detailContentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
            .contentMargins(.top, 12, for: .scrollContent)
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - App header

    private var appHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            BrandMarkImage(length: 28, cornerRadius: 7)
                .accessibilityHidden(true)
                .layoutPriority(1)

            VStack(alignment: .leading, spacing: 1) {
                Text("QueuePaste")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("Sequential paste")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .combine)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Sidebar tabs

enum SidebarTab: String, CaseIterable, Hashable {
    case load
    case queue
    case permissions

    var title: String {
        switch self {
        case .load:        return "Load Queue"
        case .queue:       return "Queue List"
        case .permissions: return "Permissions"
        }
    }

    var icon: String {
        switch self {
        case .load:        return "square.and.pencil"
        case .queue:       return "list.number"
        case .permissions: return "lock.shield"
        }
    }

    var sidebarTitle: String {
        switch self {
        case .load:        return "Prepare"
        case .queue:       return "Queue"
        case .permissions: return "Privacy"
        }
    }

    var detailNavigationTitle: String {
        switch self {
        case .load:        return "Prepare"
        case .queue:       return "Queue"
        case .permissions: return "Privacy"
        }
    }

}

#Preview {
    let vm = QueueViewModel()
    vm.loadExample()
    return ContentView()
        .environment(vm)
}
