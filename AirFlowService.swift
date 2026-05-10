import SwiftUI
import Charts

struct AirFlowService: View {

    @EnvironmentObject var state: AppState
    @StateObject private var vm = AirflowViewModel()

    @State private var selectedMenu: SidebarMenu = .dashboard

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {

        NavigationStack {

            ZStack {

                // MARK: Background

                LinearGradient(
                    colors: [
                        Color(hex: "#020817"),
                        Color(hex: "#0F172A"),
                        Color(hex: "#111827")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {

                    if selectedMenu == .settings {

                        SettingAirflowView()

                    } else {

                        VStack(alignment: .leading, spacing: 24) {

                            headerSection

                            statsSection

                            performanceSection

                            recentRunsSection

                            dagMonitorSection
                        }
                        .padding(20)
                        .padding(.bottom, 110)
                    }
                }

                VStack {

                    Spacer()

                    bottomBar
                }
            }
            .preferredColorScheme(.dark)
            .task {

                await vm.loadDAGs()

                await vm.loadDagRuns()
            }
            .refreshable {

                await vm.loadDAGs()

                await vm.loadDagRuns()
            }
        }
    }

    // MARK: Header

    private var headerSection: some View {

        VStack(alignment: .leading, spacing: 20) {

            HStack {

                VStack(alignment: .leading, spacing: 6) {

                    Text("Airflow Dashboard")
                        .font(
                            .system(
                                size: 32,
                                weight: .bold,
                                design: .rounded
                            )
                        )

                    Text("Monitor and manage DAG workflows")
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {

                    Task {

                        await vm.loadDAGs()

                        await vm.loadDagRuns()
                    }

                } label: {

                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18))
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }

            Button {

                if let firstDag = vm.dags.first {

                    Task {

                        await vm.runDAG(
                            dagID: firstDag.dagID
                        )
                    }
                }

            } label: {

                HStack(spacing: 10) {

                    Image(systemName: "play.fill")

                    Text("Run First DAG")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(

                    LinearGradient(
                        colors: [
                            Color.orange,
                            Color.orange.opacity(0.8)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(18)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Stats

    private var statsSection: some View {

        LazyVGrid(
            columns: columns,
            spacing: 16
        ) {

            DashboardCard(
                title: "Total DAGs",
                value: "\(vm.dags.count)",
                subtitle: "Connected",
                icon: "bolt.fill",
                color: .orange
            )

            DashboardCard(
                title: "Recent Runs",
                value: "\(vm.dagRuns.count)",
                subtitle: "Realtime",
                icon: "clock.fill",
                color: .blue
            )

            DashboardCard(
                title: "Success",
                value: "\(vm.successCount)",
                subtitle: "Healthy",
                icon: "checkmark.circle.fill",
                color: .green
            )

            DashboardCard(
                title: "Failed",
                value: "\(vm.failedCount)",
                subtitle: "Need Attention",
                icon: "xmark.octagon.fill",
                color: .red
            )
        }
    }

    // MARK: Performance Chart
    private var performanceSection: some View {

        VStack(alignment: .leading, spacing: 18) {

            HStack {

                Text("DAG Performance")
                    .font(.title3.bold())

                Spacer()

                Text("Realtime")
                    .foregroundColor(.secondary)
            }

            if vm.graphData.isEmpty {

                VStack(spacing: 12) {

                    Image(systemName: "chart.bar")
                        .font(.largeTitle)

                    Text("No Graph Data")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 240)

            } else {

                Chart {

                    ForEach(vm.graphData) { item in

                        BarMark(

                            x: .value(
                                "State",
                                item.day
                            ),

                            y: .value(
                                "Count",
                                item.value
                            )
                        )
                        .foregroundStyle(

                            item.day == "SUCCESS"
                            ? .green
                            : item.day == "FAILED"
                            ? .red
                            : .blue
                        )
                        .cornerRadius(8)
                        .annotation(position: .top) {

                            Text("\(Int(item.value))")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(height: 240)
                .chartYAxis {

                    AxisMarks(position: .leading)
                }
            }
        }
        .padding(22)
        .background(cardBackground)
    }

    // MARK: Recent Runs

    private var recentRunsSection: some View {

        VStack(alignment: .leading, spacing: 18) {

            HStack {

                Text("Recent DAG Runs")
                    .font(.title3.bold())

                Spacer()

                Button("Refresh") {

                    Task {

                        await vm.loadDagRuns()
                    }

                }
                .foregroundColor(.orange)
            }

            if vm.isLoading {

                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)

            } else if vm.dagRuns.isEmpty {

                Text("No DAG Runs")
                    .foregroundColor(.secondary)

            } else {

                VStack(spacing: 14) {

                    ForEach(vm.dagRuns.prefix(5)) { run in

                        AirflowRunRow(
                            dagId: run.dagID,
                            runId: run.dagRunID,
                            state: run.state
                        ) {

                            Task {

                                await vm.runDAG(
                                    dagID: run.dagID
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(22)
        .background(cardBackground)
    }

    // MARK: DAG Monitor

    private var dagMonitorSection: some View {

        VStack(alignment: .leading, spacing: 18) {

            HStack {

                Text("DAG Monitor")
                    .font(.title3.bold())

                Spacer()

                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 14) {

                ForEach(vm.dags) { dag in

                    DAGApiRow(
                        dag: dag
                    ) {

                        Task {

                            await vm.runDAG(
                                dagID: dag.dagID
                            )
                        }
                    }
                }
            }
        }
        .padding(22)
        .background(cardBackground)
    }

    // MARK: Bottom Bar

    private var bottomBar: some View {

        HStack {

            BottomBarItem(
                icon: "square.grid.2x2.fill",
                title: "Dashboard",
                isSelected: selectedMenu == .dashboard
            ) {

                selectedMenu = .dashboard
            }

            BottomBarItem(
                icon: "bolt.horizontal.circle.fill",
                title: "Runs",
                isSelected: selectedMenu == .runs
            ) {

                selectedMenu = .runs
            }

            BottomBarItem(
                icon: "chart.xyaxis.line",
                title: "Analytics",
                isSelected: selectedMenu == .analytics
            ) {

                selectedMenu = .analytics
            }

            BottomBarItem(
                icon: "gearshape.fill",
                title: "Settings",
                isSelected: selectedMenu == .settings
            ) {

                selectedMenu = .settings
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(

            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.7))
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    // MARK: Card Background

    private var cardBackground: some View {

        RoundedRectangle(cornerRadius: 26)
            .fill(Color.white.opacity(0.05))
            .overlay(

                RoundedRectangle(cornerRadius: 26)
                    .stroke(
                        Color.white.opacity(0.05),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: DAG ROW

struct DAGApiRow: View {

    let dag: AirflowDAG
    let onRun: () -> Void

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack {

                VStack(alignment: .leading, spacing: 4) {

                    Text(dag.dagID)
                        .fontWeight(.bold)

                    Text(
                        (dag.isPaused ?? false)
                        ? "Paused"
                        : "Active"
                    )
                    .font(.caption)
                    .foregroundColor(
                        (dag.isPaused ?? false)
                        ? .orange
                        : .green
                    )
                }

                Spacer()

                Circle()
                    .fill(
                        (dag.isPaused ?? false)
                        ? Color.orange
                        : Color.green
                    )
                    .frame(width: 12, height: 12)
            }

            Button {

                onRun()

            } label: {

                HStack {

                    Image(systemName: "play.fill")

                    Text("Run DAG")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(

            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.04))
        )
    }
}

// MARK: RECENT RUN ROW

struct AirflowRunRow: View {

    let dagId: String
    let runId: String
    let state: String
    let onRun: () -> Void

    private var stateColor: Color {

        switch state.lowercased() {

        case "success":
            return .green

        case "failed":
            return .red

        case "running":
            return .blue

        default:
            return .orange
        }
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack {

                VStack(alignment: .leading, spacing: 4) {

                    Text(dagId)
                        .fontWeight(.bold)

                    Text(runId)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(state.uppercased())
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(stateColor.opacity(0.15))
                    )
                    .foregroundColor(stateColor)
            }

            Button {

                onRun()

            } label: {

                HStack(spacing: 8) {

                    Image(systemName: "play.fill")

                    Text("Run Again")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(

            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
        )
    }
}

// MARK: Bottom Bar Item

struct BottomBarItem: View {

    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {

        Button(action: action) {

            VStack(spacing: 6) {

                Image(systemName: icon)
                    .font(.system(size: 18))

                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(
                isSelected
                ? .orange
                : .white.opacity(0.7)
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: Dashboard Card

struct DashboardCard: View {

    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack {

                Image(systemName: icon)
                    .foregroundColor(color)

                Spacer()

                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 42, height: 42)
                    .overlay(

                        Image(systemName: icon)
                            .foregroundColor(color)
                    )
            }

            Text(value)
                .font(.system(size: 30, weight: .bold))

            VStack(alignment: .leading, spacing: 4) {

                Text(title)
                    .foregroundColor(.secondary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(color)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(

            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: Sidebar Menu

enum SidebarMenu {

    case dashboard
    case runs
    case analytics
    case logs
    case settings
}
