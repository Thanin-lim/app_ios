import SwiftUI
import UniformTypeIdentifiers
import QuickLook

#if os(macOS)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif

struct ExplorerView: View {

    @EnvironmentObject var state: AppState

    // MARK: - Responsive

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

    // MARK: - State

    @State private var showingNewFolderSheet = false
    @State private var showingFilePicker = false
    @State private var objectToDelete: MinIOObject? = nil
    @State private var showingDeleteAlert = false

    // ✅ QuickLook state
    @State private var previewURL: URL? = nil
    @State private var isLoadingPreview = false
    @State private var previewObj: MinIOObject? = nil

    // MARK: - Body

    var body: some View {

        VStack(spacing: 0) {

            // MARK: Toolbar

            HStack(spacing: isCompactPhone ? 8 : 12) {

                Button {
                    Task {
                        await state.goBack()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(
                            isCompactPhone
                            ? .body.bold()
                            : .title3.bold()
                        )
                }
                .disabled(state.currentPath.isEmpty)

                #if os(macOS)
                .buttonStyle(.borderless)
                #endif

                Text("Explorer")
                    .font(
                        .system(
                            size: isCompactPhone ? 18 : 22,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                Button {
                    showingNewFolderSheet = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .buttonStyle(.bordered)

                Button {
                    showingFilePicker = true
                } label: {
                    Image(systemName: "arrow.up.doc")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, isCompactPhone ? 12 : 20)
            .padding(.vertical, 10)

            // MARK: Breadcrumbs

            ScrollView(.horizontal, showsIndicators: false) {

                HStack(spacing: 4) {

                    ForEach(
                        Array(state.breadcrumbs.enumerated()),
                        id: \.offset
                    ) { idx, crumb in

                        if idx > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Button(crumb.label) {
                            Task {
                                await state.navigateTo(crumb.path)
                            }
                        }
                        #if os(macOS)
                        .buttonStyle(.plain)
                        #endif
                        .foregroundColor(
                            idx == state.breadcrumbs.count - 1
                            ? .primary
                            : .blue
                        )
                        .font(
                            isCompactPhone
                            ? .caption
                            : .subheadline
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .background(Color.secondary.opacity(0.08))

            Divider()

            // MARK: Content

            if state.isLoading && state.objects.isEmpty {

                Spacer()
                ProgressView("Loading...")
                    .controlSize(.large)
                Spacer()

            } else if state.objects.isEmpty {

                emptyStateView

            } else {

                List {

                    ForEach(state.objects) { obj in

                        FileRow(
                            obj: obj,
                            isCompactPhone: isCompactPhone,
                            isLoadingPreview: previewObj?.id == obj.id && isLoadingPreview
                        ) {

                            if obj.isDirectory {
                                Task { await state.navigateTo(obj.name) }
                            }

                        } onDownload: {

                            openPreview(obj)

                        } onDelete: {

                            objectToDelete = obj
                            showingDeleteAlert = true
                        }

                        // MARK: Swipe Actions

                        .swipeActions(edge: .trailing) {

                            Button(role: .destructive) {
                                objectToDelete = obj
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            if !obj.isDirectory {
                                Button {
                                    openPreview(obj)
                                } label: {
                                    Label("Open", systemImage: "eye")
                                }
                                .tint(.blue)
                            }
                        }

                        // MARK: Context Menu

                        .contextMenu {

                            if !obj.isDirectory {
                                Button {
                                    openPreview(obj)
                                } label: {
                                    Label("Open / Preview", systemImage: "eye")
                                }
                            }

                            Button(role: .destructive) {
                                objectToDelete = obj
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                #if os(macOS)
                .listStyle(.inset(alternatesRowBackgrounds: true))
                #else
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                #endif
                .padding(.bottom, 4)
            }
        }
        .dynamicTypeSize(.small ... .large)

        // MARK: QuickLook Preview
        // ✅ iOS: ใช้ .quickLookPreview — เปิดใน sheet ในแอปเลย ไม่ออก Safari
        #if os(iOS)
        .quickLookPreview($previewURL)
        #endif

        // MARK: New Folder Sheet

        .sheet(isPresented: $showingNewFolderSheet) {
            NewFolderSheet(isPresented: $showingNewFolderSheet) { name in
                Task { await state.createFolder(name: name) }
            }
        }

        // MARK: Delete Alert

        .alert(
            "Delete \"\(objectToDelete?.displayName ?? "")\"?",
            isPresented: $showingDeleteAlert
        ) {
            Button("Delete", role: .destructive) {
                if let obj = objectToDelete {
                    Task { await state.deleteObject(obj.name) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }

        // MARK: File Importer

        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in

            if case .success(let urls) = result {
                for url in urls {
                    let _ = url.startAccessingSecurityScopedResource()
                    Task {
                        await state.uploadFile(
                            localURL: url,
                            remoteName: url.lastPathComponent
                        )
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            }
        }

        .task {
            await state.loadFiles()
        }
    }

    // MARK: Empty State

    private var emptyStateView: some View {
        VStack {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 52))
                    .foregroundColor(.secondary.opacity(0.4))
                Text("Empty folder")
                    .font(.headline)
                Text("Upload files or create a folder.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(.secondary)
            .padding()
            Spacer()
        }
    }

    // MARK: Open Preview (QuickLook)

    // ✅ Download ไฟล์ไปไว้ใน temp ก่อน แล้วเปิด QuickLook ในแอป
    // QuickLook ต้องการ local file URL — ไม่รับ remote URL โดยตรง
    private func openPreview(_ obj: MinIOObject) {
        Task {
            guard let remoteURL = await state.presignedURL(for: obj.name) else { return }

            #if os(iOS)
            previewObj = obj
            isLoadingPreview = true

            do {
                // Download ไฟล์ไปไว้ใน temp directory
                let (tmpURL, _) = try await URLSession.shared.download(from: remoteURL)

                // ตั้งชื่อไฟล์ให้ถูก extension — QuickLook ใช้ extension ในการเลือก renderer
                let fileName = obj.displayName
                let destURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(fileName)

                // ลบไฟล์เก่าถ้ามีอยู่
                try? FileManager.default.removeItem(at: destURL)
                try FileManager.default.moveItem(at: tmpURL, to: destURL)

                isLoadingPreview = false
                previewObj = nil
                previewURL = destURL  // ✅ set ตรงนี้ → .quickLookPreview เปิดเอง

            } catch {
                isLoadingPreview = false
                previewObj = nil
                print("[Preview] download error: \(error)")
            }

            #else
            // macOS — เปิดใน Quick Look ผ่าน NSWorkspace
            NSWorkspace.shared.open(remoteURL)
            #endif
        }
    }
}

// MARK: - File Row

struct FileRow: View {

    let obj: MinIOObject
    let isCompactPhone: Bool
    let isLoadingPreview: Bool  // ✅ แสดง spinner ระหว่าง download

    let onTap: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {

        HStack(spacing: 10) {

            // MARK: Icon

            ZStack {

                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        obj.isDirectory
                        ? Color.yellow.opacity(0.15)
                        : Color.blue.opacity(0.10)
                    )
                    .frame(
                        width: isCompactPhone ? 36 : 42,
                        height: isCompactPhone ? 36 : 42
                    )

                if isLoadingPreview {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(
                        systemName:
                            obj.isDirectory
                            ? "folder.fill"
                            : fileIcon(for: obj.name)
                    )
                    .font(.system(size: isCompactPhone ? 16 : 18))
                    .foregroundColor(obj.isDirectory ? .orange : .blue)
                }
            }

            // MARK: File Info

            VStack(alignment: .leading, spacing: 2) {

                Text(obj.displayName)
                    .font(
                        .system(
                            size: isCompactPhone ? 14 : 15,
                            weight: .medium
                        )
                    )
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .minimumScaleFactor(0.8)

                Text(
                    obj.isDirectory
                    ? "Directory"
                    : subtitleText
                )
                .font(isCompactPhone ? .caption2 : .caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            // MARK: macOS Hover Buttons

            #if os(macOS)
            if isHovered {
                HStack(spacing: 8) {
                    if !obj.isDirectory {
                        Button(action: onDownload) {
                            Image(systemName: "eye.circle")
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            #endif
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        #if os(macOS)
        .onHover { isHovered = $0 }
        #endif
        .padding(.vertical, 2)
    }

    // MARK: Subtitle

    private var subtitleText: String {
        let sizeStr = AppState.formatSize(obj.size)
        if let date = obj.lastModified {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return "\(sizeStr) • \(formatter.string(from: date))"
        }
        return sizeStr
    }

    // MARK: File Icon

    private func fileIcon(for name: String) -> String {
        let ext = name
            .split(separator: ".")
            .last
            .map(String.init)?
            .lowercased() ?? ""

        switch ext {
        case "pdf":             return "doc.richtext.fill"
        case "png", "jpg",
             "jpeg", "gif",
             "webp":            return "photo.fill"
        case "mp4", "mov",
             "avi":             return "film.fill"
        case "zip", "rar":      return "archivebox.fill"
        case "txt":             return "doc.text.fill"
        case "csv":             return "tablecells.fill"
        case "json":            return "curlybraces"
        default:                return "doc.fill"
        }
    }
}

// MARK: - New Folder Sheet

struct NewFolderSheet: View {

    @Binding var isPresented: Bool
    let onCreate: (String) -> Void
    @State private var name = ""

    var body: some View {

        #if os(iOS)
        NavigationView {
            formContent
                .navigationTitle("New Folder")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isPresented = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") { submit() }
                            .disabled(name.isEmpty)
                    }
                }
        }
        #else
        VStack(spacing: 20) {
            Text("New Folder").font(.headline)
            TextField("Folder name", text: $name).textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { isPresented = false }
                Button("Create") { submit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 320)
        #endif
    }

    private var formContent: some View {
        Form {
            TextField("Folder name", text: $name)
                .autocorrectionDisabled()
        }
    }

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            onCreate(trimmed)
            isPresented = false
        }
    }
}
