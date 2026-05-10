import SwiftUI
import Charts

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    StatsGridSection(state: state)
                    ChartSection(state: state)
                    RecentFilesSection(state: state)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .refreshable {
                // ผู้ใช้ใช้นิ้วดึงหน้าจอลงเพื่อโหลดข้อมูลล่าสุดได้เลย
                await state.loadFiles()
            }
        }
        .navigationTitle("Overview")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await state.loadFiles() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .rotationEffect(.degrees(state.isLoading ? 360 : 0))
                        .animation(
                            state.isLoading
                                ? .linear(duration: 1).repeatForever(autoreverses: false)
                                : .default,
                            value: state.isLoading
                        )
                }
                .disabled(state.isLoading) // ปิดปุ่มตอนกำลังโหลด ป้องกันกดย้ำๆ
            }
        }
    }
}

// MARK: - Stats Grid

struct StatsGridSection: View {
    @ObservedObject var state: AppState // ✅ แก้เป็น @ObservedObject แล้ว
    let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            StatCard(
                title: "Files",
                value: "\(state.totalFiles)",
                icon: "doc.on.doc.fill",
                color: .blue
            )
            StatCard(
                title: "Usage",
                value: AppState.formatSize(state.totalSize),
                icon: "internaldrive.fill",
                color: Color(red: 0.2, green: 0.83, blue: 0.6)
            )
            StatCard(
                title: "Types",
                value: "\(state.fileTypeStats.count)",
                icon: "square.grid.2x2.fill",
                color: Color(red: 0.65, green: 0.55, blue: 0.98)
            )
            StatCard(
                title: "Status",
                value: state.isLoading ? "Loading" : "Online",
                icon: "bolt.fill",
                color: .orange
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 110)
        .padding(14)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.09), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Chart Section

struct ChartSection: View {
    @ObservedObject var state: AppState // ✅ แก้เป็น @ObservedObject แล้ว

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader

            if state.fileTypeStats.isEmpty {
                emptyChart
            } else {
                donutChart
                legendList
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    var sectionHeader: some View {
        HStack {
            Text("Storage distribution")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Text("\(state.fileTypeStats.count) types")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.35))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    var emptyChart: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.pie")
                .font(.system(size: 30))
                .foregroundColor(.gray)
            Text("No data available")
                .foregroundColor(.gray)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
    }

    var donutChart: some View {
        ZStack {
            Chart(state.fileTypeStats) { stat in
                SectorMark(
                    angle: .value("Count", stat.count),
                    innerRadius: .ratio(0.65),
                    angularInset: 3
                )
                .foregroundStyle(stat.color)
                .cornerRadius(6)
            }
            VStack(spacing: 2) {
                Text("\(state.totalFiles)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Files")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .frame(height: 180)
    }

    var legendList: some View {
        let maxCount = state.fileTypeStats.map { $0.count }.max() ?? 1
        return VStack(spacing: 10) {
            ForEach(state.fileTypeStats) { stat in
                LegendRow(stat: stat, maxCount: maxCount)
            }
        }
    }
}

// MARK: - Legend Row

struct LegendRow: View {
    let stat: FileTypeStats
    let maxCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(stat.color)
                .frame(width: 9, height: 9)

            Text(stat.ext.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 42, alignment: .leading)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 5)

                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(stat.color.opacity(0.85))
                        .frame(
                            width: geo.size.width * CGFloat(stat.count) / CGFloat(maxCount),
                            height: 5
                        )
                }
                .frame(height: 5)
            }

            Text("\(stat.count)")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 36, alignment: .trailing)
        }
    }
}

// MARK: - Recent Files Section

// MARK: - Recent Files Section
struct RecentFilesSection: View {

    @ObservedObject var state: AppState

    var body: some View {

        let recent = state.allObjects
            .filter { !$0.isDirectory }

            .sorted {

                ($0.lastModified ?? .distantPast)
                >
                ($1.lastModified ?? .distantPast)
            }

            .prefix(5)

        VStack(alignment: .leading, spacing: 14) {

            HStack {

                Text("Recent files")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(recent.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if recent.isEmpty {

                VStack(spacing: 10) {

                    Image(systemName: "folder")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)

                    Text("No recent files")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)

            } else {

                VStack(spacing: 8) {

                    ForEach(Array(recent)) { obj in

                        DashboardFileRow(obj: obj)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .overlay(

            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    Color.white.opacity(0.08),
                    lineWidth: 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}



// MARK: - Dashboard File Row

struct DashboardFileRow: View {
    let obj: MinIOObject

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 44, height: 44)
                Image(systemName: fileIcon(for: obj.name))
                    .font(.system(size: 19))
                    .foregroundColor(iconColor(for: obj.name))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(obj.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(AppState.formatSize(obj.size))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))

                    let ext = fileExt(for: obj.name)
                    if !ext.isEmpty {
                        let c = iconColor(for: obj.name)
                        Text(ext.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(c)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(c.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.22))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    func fileExt(for name: String) -> String {
        name.split(separator: ".").last.map(String.init) ?? ""
    }

    func fileIcon(for name: String) -> String {
        switch fileExt(for: name).lowercased() {
        case "pdf":                return "doc.richtext.fill"
        case "png", "jpg", "jpeg": return "photo.fill"
        case "doc", "docx":        return "doc.text.fill"
        case "zip":                return "archivebox.fill"
        case "mp4", "mov":         return "video.fill"
        default:                   return "doc.fill"
        }
    }

    func iconColor(for name: String) -> Color {
            // ดึงสีมาจากฟังก์ชันกลางที่ล็อคไว้แล้วใน AppState
            let ext = fileExt(for: name)
            return AppState.colorForExtension(ext)
        }
    
}
