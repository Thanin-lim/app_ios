import SwiftUI

// MARK: - Main View

struct MainView: View {

    @EnvironmentObject var state: AppState

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var isCompactPhone: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }

    var body: some View {
        Group {
            #if os(iOS)
            if isCompactPhone {
                tabLayout
            } else {
                splitViewLayout
            }
            #else
            splitViewLayout
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - iPhone Tab Layout

extension MainView {

    var tabLayout: some View {

        TabView(selection: $state.selectedTab) {

            NavigationStack {
                DashboardView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
            .tabItem {
                Label("Overview", systemImage: "square.grid.2x2.fill")
            }
            .tag(0)

            NavigationStack {
                ExplorerView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
            .tabItem {
                Label("Explorer", systemImage: "folder.fill")
            }
            .tag(1)

            NavigationStack {
                SettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(2)
        }
        .tint(.blue)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - iPad / macOS Split Layout

extension MainView {

    var splitViewLayout: some View {

        NavigationSplitView {
            SidebarView()
        } detail: {
            NavigationStack {
                contentArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(Color.black)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                Task { await state.loadFiles() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
                    .navigationTitle("Bucket: \(state.bucketName)")
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - Content Area

extension MainView {

    @ViewBuilder
    var contentArea: some View {
        switch state.selectedTab {
        case 0:
            DashboardView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case 1:
            ExplorerView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case 2:
            SettingsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        default:
            DashboardView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {

    @EnvironmentObject var state: AppState

    var body: some View {

        List {
            Section("Navigation") {
                sidebarButton(title: "Overview", icon: "square.grid.2x2.fill", tab: 0)
                sidebarButton(title: "Explorer", icon: "folder.fill", tab: 1)
                sidebarButton(title: "Settings", icon: "gearshape.fill", tab: 2)
            }

            Section("Storage") {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "externaldrive.fill")
                        .foregroundColor(.blue)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.bucketName)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Text(AppState.formatSize(state.totalSize))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))

        #if os(macOS)
        .frame(minWidth: 240)
        #endif
    }
}

extension SidebarView {

    @ViewBuilder
    func sidebarButton(title: String, icon: String, tab: Int) -> some View {

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                state.selectedTab = tab
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
                if state.selectedTab == tab {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.caption.bold())
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("iPhone 13 Pro") {
    MainView()
        .environmentObject(AppState())
        .previewDevice("iPhone 13 Pro MAX")
}

#Preview("iPad Pro") {
    MainView()
        .environmentObject(AppState())
        .previewDevice("iPad Pro (11-inch)")
}

#Preview("Mac") {
    MainView()
        .environmentObject(AppState())
}
