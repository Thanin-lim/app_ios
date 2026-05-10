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

                modernTabLayout

            } else {

                modernSidebarLayout
            }

            #else

            modernSidebarLayout

            #endif
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Mobile Layout

extension MainView {

    var modernTabLayout: some View {

        ZStack(alignment: .bottom) {

            backgroundLayer

            TabView(selection: $state.selectedTab) {

                DashboardView()
                    .tag(0)

                ExplorerView()
                    .tag(1)

                SettingsView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // MARK: Floating Bottom Navigation

            HStack(spacing: 8) {

                bottomTabButton(
                    title: "Overview",
                    icon: "square.grid.2x2.fill",
                    tab: 0
                )

                bottomTabButton(
                    title: "Explorer",
                    icon: "folder.fill",
                    tab: 1
                )

                bottomTabButton(
                    title: "Settings",
                    icon: "gearshape.fill",
                    tab: 2
                )
            }
            .padding(10)
            .background(

                RoundedRectangle(cornerRadius: 26)
                    .fill(Color.black.opacity(0.72))

                    .overlay(

                        RoundedRectangle(cornerRadius: 26)
                            .stroke(
                                Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Sidebar Layout

extension MainView {

    var modernSidebarLayout: some View {

        NavigationSplitView {

            modernSidebar

        } detail: {

            ZStack {

                backgroundLayer

                NavigationStack {

                    ScrollView {

                        contentArea
                            .padding(24)
                    }
                    .toolbar {

                        ToolbarItemGroup(
                            placement: .primaryAction
                        ) {

                            Button {

                                Task {
                                    await state.loadFiles()
                                }

                            } label: {

                                Image(
                                    systemName:
                                        "arrow.clockwise"
                                )
                            }

                            Button {

                            } label: {

                                Image(
                                    systemName:
                                        "bell.badge.fill"
                                )
                            }
                        }
                    }
                    .navigationTitle(
                        state.bucketName.isEmpty
                        ? "MinIO Dashboard"
                        : state.bucketName
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Sidebar

extension MainView {

    var modernSidebar: some View {

        ZStack {

            Color(hex: "#0F172A")
                .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 26
            ) {

                // MARK: Logo

                HStack(spacing: 14) {

                    RoundedRectangle(cornerRadius: 18)
                        .fill(

                            LinearGradient(
                                colors: [
                                    .blue,
                                    .cyan
                                ],
                                startPoint: .topLeading,
                                endPoint:
                                    .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)

                        .overlay(

                            Image(
                                systemName:
                                    "externaldrive.fill"
                            )
                            .font(.title2)
                            .foregroundColor(.white)
                        )

                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {

                        Text("MinIO")
                            .font(
                                .system(
                                    size: 24,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )

                        Text("Storage Platform")
                            .font(.caption)
                            .foregroundColor(
                                .secondary
                            )
                    }
                }
                .padding(.horizontal)

                // MARK: Menu

                VStack(spacing: 12) {

                    sidebarButton(
                        title: "Overview",
                        icon:
                            "square.grid.2x2.fill",
                        tab: 0
                    )

                    sidebarButton(
                        title: "Explorer",
                        icon: "folder.fill",
                        tab: 1
                    )

                    sidebarButton(
                        title: "Settings",
                        icon:
                            "gearshape.fill",
                        tab: 2
                    )
                }
                .padding(.horizontal)

                Spacer()

                // MARK: Storage Card

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {

                    HStack {

                        Circle()
                            .fill(
                                Color.blue.opacity(
                                    0.2
                                )
                            )
                            .frame(
                                width: 42,
                                height: 42
                            )

                            .overlay(

                                Image(
                                    systemName:
                                        "externaldrive.fill"
                                )
                                .foregroundColor(
                                    .blue
                                )
                            )

                        Spacer()
                    }

                    Text(state.bucketName)
                        .fontWeight(.bold)

                    Text(
                        AppState.formatSize(
                            state.totalSize
                        )
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(

                    RoundedRectangle(
                        cornerRadius: 22
                    )
                    .fill(
                        Color.white.opacity(0.05)
                    )
                )
                .padding()
            }
            .padding(.top, 20)
        }
        .frame(minWidth: 280)
    }
}

// MARK: - Content Area

extension MainView {

    @ViewBuilder
    var contentArea: some View {

        switch state.selectedTab {

        case 0:

            DashboardView()

        case 1:

            ExplorerView()

        case 2:

            SettingsView()

        default:

            DashboardView()
        }
    }
}

// MARK: - Sidebar Button

extension MainView {

    @ViewBuilder
    func sidebarButton(
        title: String,
        icon: String,
        tab: Int
    ) -> some View {

        Button {

            withAnimation(.easeInOut) {

                state.selectedTab = tab
            }

        } label: {

            HStack(spacing: 14) {

                Image(systemName: icon)
                    .frame(width: 20)

                Text(title)
                    .fontWeight(.medium)

                Spacer()

                if state.selectedTab == tab {

                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 52)

            .background(

                RoundedRectangle(
                    cornerRadius: 16
                )
                .fill(
                    state.selectedTab == tab
                    ? Color.blue.opacity(0.18)
                    : Color.clear
                )
            )
            .foregroundColor(
                state.selectedTab == tab
                ? .blue
                : .white
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bottom Tab Button

extension MainView {

    @ViewBuilder
    func bottomTabButton(
        title: String,
        icon: String,
        tab: Int
    ) -> some View {

        Button {

            withAnimation(.easeInOut) {

                state.selectedTab = tab
            }

        } label: {

            VStack(spacing: 6) {

                Image(systemName: icon)
                    .font(.system(size: 18))

                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(
                state.selectedTab == tab
                ? .blue
                : .white.opacity(0.7)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Background

extension MainView {

    var backgroundLayer: some View {

        LinearGradient(
            colors: [
                Color(hex: "#020617"),
                Color(hex: "#0F172A"),
                Color(hex: "#111827")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview("iPhone") {

    MainView()
        .environmentObject(AppState())
}

#Preview("iPad") {

    MainView()
        .environmentObject(AppState())
}

#Preview("Mac") {

    MainView()
        .environmentObject(AppState())
}
