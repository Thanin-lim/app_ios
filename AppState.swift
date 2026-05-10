//
//  AppState.swift
//  warvba.thanin.test
//
//  Created by warvba on 10/5/2569 BE.
//

import Foundation
import SwiftUI
internal import Combine

// MARK: - Models

struct MinIOObject: Identifiable {

    let id = UUID()

    let name: String
    let displayName: String
    let isDirectory: Bool
    let size: Int64
    let lastModified: Date?
}

struct FileTypeStats: Identifiable {

    let id = UUID()

    let ext: String
    let count: Int
    let color: Color
}

// MARK: - App State

class AppState: ObservableObject {

    // MARK: - Connection

    @Published var host: String = "100.106.98.53:30005"
    @Published var accessKey: String = "minio"
    @Published var secretKey: String = "minio123"
    @Published var bucketName: String = "mybucket"

    // MARK: - Navigation

    @Published var currentPath: String = ""
    @Published var isLoggedIn: Bool = false

    // MARK: - Data

    @Published var objects: [MinIOObject] = []
    @Published var allObjects: [MinIOObject] = []
    @Published var fileTypeStats: [FileTypeStats] = []

    @Published var totalSize: Int64 = 0

    @Published var statusMessage: String = "Ready"

    @Published var isLoading: Bool = false

    @Published var errorMessage: String? = nil

    // MARK: - Selected Tab

    @Published var selectedTab: Int = 0

    // MARK: - Breadcrumbs

    var breadcrumbs: [(label: String, path: String)] {

        var crumbs: [(String, String)] = [(bucketName, "")]

        if !currentPath.isEmpty {

            let parts = currentPath
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .split(separator: "/")

            var accumulated = ""

            for part in parts {

                accumulated += "\(part)/"

                crumbs.append((String(part), accumulated))
            }
        }

        return crumbs
    }

    // MARK: - Total Files

    var totalFiles: Int {

        allObjects.filter { !$0.isDirectory }.count
    }

    // MARK: - Recent Files
    // เรียงจากใหม่ → เก่า สูงสุด 5 รายการ

    var recentFiles: [MinIOObject] {

        allObjects
            .filter { !$0.isDirectory }
            .sorted {
                ($0.lastModified ?? .distantPast)
                >
                ($1.lastModified ?? .distantPast)
            }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - File Count By Extension

    var fileCountByExtension: [String: Int] {

        var result: [String: Int] = [:]

        for obj in allObjects where !obj.isDirectory {

            let ext = obj.name.contains(".")
                ? String(obj.name.split(separator: ".").last ?? "other").lowercased()
                : "other"

            result[ext, default: 0] += 1
        }

        return result
    }

    // MARK: - Login

    func login(
        host: String,
        accessKey: String,
        secretKey: String,
        bucket: String
    ) async -> Bool {

        await MainActor.run {

            isLoading = true
            errorMessage = nil
        }

        let success = await MinIOService.shared.connect(
            host: host,
            accessKey: accessKey,
            secretKey: secretKey,
            bucket: bucket
        )

        await MainActor.run {

            if success {

                self.host = host
                self.accessKey = accessKey
                self.secretKey = secretKey
                self.bucketName = bucket

                self.currentPath = ""

                self.isLoggedIn = true

            } else {

                self.errorMessage = "Connection failed. Check your credentials."
            }

            self.isLoading = false
        }

        if success {

            await loadFiles()
        }

        return success
    }

    // MARK: - Load Files

    func loadFiles() async {

        guard isLoggedIn else { return }

        await MainActor.run {

            isLoading = true
        }

        let (current, all) = await MinIOService.shared.listObjects(
            bucket: bucketName,
            prefix: currentPath
        )

        await MainActor.run {

            self.objects = current

            self.allObjects = all

            self.totalSize = all
                .filter { !$0.isDirectory }
                .reduce(0) { $0 + $1.size }

            self.buildStats(from: all)

            self.statusMessage = "Last updated: \(Self.timeString())"

            self.isLoading = false
        }
    }

    // MARK: - Refresh

    func refresh() async {
        await loadFiles()
    }

    /// Auto-refresh ทุก N วินาที — ใช้ใน .task { await state.startAutoRefresh() }
    func startAutoRefresh(interval: TimeInterval = 30) async {

        while !Task.isCancelled && isLoggedIn {

            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

            guard isLoggedIn else { break }

            await loadFiles()
        }
    }

    // MARK: - Navigation

    func navigateTo(_ path: String) async {

        await MainActor.run {

            currentPath = path
        }

        await loadFiles()
    }

    func goBack() async {

        guard !currentPath.isEmpty else { return }

        var parts = currentPath
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")

        parts.removeLast()

        let newPath = parts.isEmpty
            ? ""
            : parts.joined(separator: "/") + "/"

        await navigateTo(newPath)
    }

    // MARK: - Folder

    func createFolder(name: String) async {

        var folderName = name.trimmingCharacters(in: .whitespaces)

        if !folderName.hasSuffix("/") {

            folderName += "/"
        }

        let fullPath = currentPath + folderName

        await MinIOService.shared.putEmptyObject(
            bucket: bucketName,
            key: fullPath
        )

        await loadFiles()
    }

    // MARK: - Delete Single

    func deleteObject(_ key: String) async {

        await MinIOService.shared.removeObject(
            bucket: bucketName,
            key: key
        )

        await loadFiles()
    }

    // MARK: - Batch Delete
    // ลบหลายไฟล์พร้อมกัน (concurrent)

    func deleteObjects(keys: [String]) async {

        await withTaskGroup(of: Void.self) { group in

            for key in keys {

                group.addTask {
                    await MinIOService.shared.removeObject(
                        bucket: self.bucketName,
                        key: key
                    )
                }
            }
        }

        await loadFiles()
    }

    // MARK: - Rename
    // MinIO ไม่มี native rename → copy แล้ว delete ต้นฉบับ

    func renameObject(oldKey: String, newName: String) async {

        var components = oldKey
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .map(String.init)

        guard !components.isEmpty else { return }

        components[components.count - 1] = newName

        let newKey = components.joined(separator: "/")

        await MinIOService.shared.copyObject(
            bucket: bucketName,
            sourceKey: oldKey,
            destinationKey: newKey
        )

        await MinIOService.shared.removeObject(
            bucket: bucketName,
            key: oldKey
        )

        await loadFiles()
    }

    // MARK: - Move
    // ย้ายไฟล์ไปยัง path ปลายทาง

    func moveObject(sourceKey: String, destinationPath: String) async {

        let fileName = sourceKey
            .split(separator: "/")
            .last
            .map(String.init) ?? sourceKey

        let destinationKey = destinationPath.isEmpty
            ? fileName
            : destinationPath + fileName

        await MinIOService.shared.copyObject(
            bucket: bucketName,
            sourceKey: sourceKey,
            destinationKey: destinationKey
        )

        await MinIOService.shared.removeObject(
            bucket: bucketName,
            key: sourceKey
        )

        await loadFiles()
    }

    // MARK: - URL

    func presignedURL(for key: String) async -> URL? {

        return await MinIOService.shared.presignedGetURL(
            bucket: bucketName,
            key: key,
            expiresIn: 3600
        )
    }

    // MARK: - Upload File

    func uploadFile(localURL: URL, remoteName: String) async {

        let key = currentPath + remoteName

        await MinIOService.shared.uploadFile(
            bucket: bucketName,
            key: key,
            localURL: localURL
        )

        await loadFiles()
    }

    // MARK: - Download File
    // ดาวน์โหลดไฟล์ไปยัง local directory

    func downloadFile(
        key: String,
        to directory: URL = FileManager.default.temporaryDirectory
    ) async -> URL? {

        guard let remoteURL = await presignedURL(for: key) else { return nil }

        let fileName = key
            .split(separator: "/")
            .last
            .map(String.init) ?? key

        let localURL = directory.appendingPathComponent(fileName)

        do {

            let (data, _) = try await URLSession.shared.data(from: remoteURL)

            try data.write(to: localURL)

            return localURL

        } catch {

            await MainActor.run {
                errorMessage = "Download failed: \(error.localizedDescription)"
            }

            return nil
        }
    }

    // MARK: - Search

    /// ค้นหาไฟล์/โฟลเดอร์จาก keyword (case-insensitive)
    func search(keyword: String) -> [MinIOObject] {

        guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else {
            return objects
        }

        return allObjects.filter {
            $0.displayName.localizedCaseInsensitiveContains(keyword)
        }
    }

    func searchFiles(keyword: String) -> [MinIOObject] {
        search(keyword: keyword).filter { !$0.isDirectory }
    }

    func searchFolders(keyword: String) -> [MinIOObject] {
        search(keyword: keyword).filter { $0.isDirectory }
    }

    // MARK: - Sort

    enum SortOption {
        case nameAsc, nameDesc
        case sizeAsc, sizeDesc
        case dateAsc, dateDesc
    }

    func sorted(_ items: [MinIOObject], by option: SortOption) -> [MinIOObject] {

        switch option {

        case .nameAsc:
            return items.sorted {
                $0.displayName.localizedCompare($1.displayName) == .orderedAscending
            }

        case .nameDesc:
            return items.sorted {
                $0.displayName.localizedCompare($1.displayName) == .orderedDescending
            }

        case .sizeAsc:
            return items.sorted { $0.size < $1.size }

        case .sizeDesc:
            return items.sorted { $0.size > $1.size }

        case .dateAsc:
            return items.sorted {
                ($0.lastModified ?? .distantPast) < ($1.lastModified ?? .distantPast)
            }

        case .dateDesc:
            return items.sorted {
                ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast)
            }
        }
    }

    func sortedObjects(by option: SortOption) -> [MinIOObject] {
        sorted(objects, by: option)
    }

    // MARK: - Filter

    enum FilterOption {
        case all
        case filesOnly
        case foldersOnly
        case byExtension(String)
        case largerThan(Int64)
        case smallerThan(Int64)
        case modifiedAfter(Date)
        case modifiedBefore(Date)
    }

    func filter(_ items: [MinIOObject], by option: FilterOption) -> [MinIOObject] {

        switch option {

        case .all:
            return items

        case .filesOnly:
            return items.filter { !$0.isDirectory }

        case .foldersOnly:
            return items.filter { $0.isDirectory }

        case .byExtension(let ext):
            return items.filter {
                !$0.isDirectory && $0.name.hasSuffix(".\(ext.lowercased())")
            }

        case .largerThan(let bytes):
            return items.filter { $0.size > bytes }

        case .smallerThan(let bytes):
            return items.filter { $0.size < bytes }

        case .modifiedAfter(let date):
            return items.filter {
                ($0.lastModified ?? .distantPast) > date
            }

        case .modifiedBefore(let date):
            return items.filter {
                ($0.lastModified ?? .distantFuture) < date
            }
        }
    }

    func filteredObjects(by option: FilterOption) -> [MinIOObject] {
        filter(objects, by: option)
    }

    // MARK: - Folder Size

    func folderSize(prefix: String) -> Int64 {

        allObjects
            .filter { !$0.isDirectory && $0.name.hasPrefix(prefix) }
            .reduce(0) { $0 + $1.size }
    }

    // MARK: - Exists Check

    func exists(name: String, inPath path: String? = nil) -> Bool {

        let checkPath = (path ?? currentPath) + name

        return allObjects.contains {
            $0.name == checkPath || $0.name == checkPath + "/"
        }
    }

    // MARK: - Error Handling

    func showError(_ message: String, autoClear: Bool = true) {

        Task { @MainActor in

            errorMessage = message

            if autoClear {

                try? await Task.sleep(nanoseconds: 3_000_000_000)

                errorMessage = nil
            }
        }
    }

    func clearError() {

        Task { @MainActor in
            errorMessage = nil
        }
    }

    // MARK: - Logout

    func logout() {

        isLoggedIn = false

        objects = []

        allObjects = []

        fileTypeStats = []

        currentPath = ""

        statusMessage = "Ready"
    }

    // MARK: - Reconnect

    func reconnect() async {

        _ = await login(
            host: host,
            accessKey: accessKey,
            secretKey: secretKey,
            bucket: bucketName
        )
    }

    // MARK: - File Extension Color

    static func colorForExtension(_ ext: String) -> Color {

        switch ext.lowercased() {

        case "pdf":
            return Color(red: 0.90, green: 0.23, blue: 0.21)

        case "doc", "docx":
            return Color(red: 0.24, green: 0.47, blue: 0.85)

        case "xls", "xlsx", "csv":
            return Color(red: 0.20, green: 0.65, blue: 0.38)

        case "ppt", "pptx":
            return Color(red: 0.95, green: 0.49, blue: 0.20)

        case "png", "jpg", "jpeg", "heic", "gif", "webp":
            return Color(red: 0.56, green: 0.36, blue: 0.96)

        case "zip", "rar", "7z", "tar", "gz":
            return Color(red: 0.55, green: 0.55, blue: 0.58)

        case "mp4", "mov", "avi", "mkv":
            return Color(red: 0.89, green: 0.27, blue: 0.58)

        case "mp3", "wav", "aac", "flac":
            return Color(red: 0.18, green: 0.72, blue: 0.72)

        case "swift", "py", "js", "ts", "json", "html", "css", "java", "kt":
            return Color(red: 0.98, green: 0.73, blue: 0.18)

        case "txt", "md", "rtf":
            return Color(red: 0.42, green: 0.50, blue: 0.60)

        case "other":
            return Color(red: 0.60, green: 0.60, blue: 0.67)

        default:
            let palette: [Color] = [
                Color(red: 0.36, green: 0.54, blue: 0.96),
                Color(red: 0.52, green: 0.68, blue: 0.28),
                Color(red: 0.84, green: 0.43, blue: 0.26),
                Color(red: 0.64, green: 0.45, blue: 0.91),
                Color(red: 0.20, green: 0.70, blue: 0.70),
                Color(red: 0.85, green: 0.38, blue: 0.48)
            ]
            let hash = abs(ext.hashValue)
            return palette[hash % palette.count]
        }
    }

    // MARK: - Build Stats

    private func buildStats(from objs: [MinIOObject]) {

        var extCounts: [String: Int] = [:]

        for obj in objs where !obj.isDirectory {

            let ext: String

            if obj.name.contains(".") {

                ext = String(
                    obj.name
                        .split(separator: ".")
                        .last ?? "other"
                )
                .lowercased()

            } else {

                ext = "other"
            }

            extCounts[ext, default: 0] += 1
        }

        fileTypeStats = extCounts.map { kv in

            FileTypeStats(
                ext: kv.key.uppercased(),
                count: kv.value,
                color: Self.colorForExtension(kv.key)
            )
        }
        .sorted { $0.count > $1.count }
    }

    // MARK: - Time String

    static func timeString() -> String {

        let formatter = DateFormatter()

        formatter.dateFormat = "HH:mm:ss"

        return formatter.string(from: Date())
    }

    // MARK: - Format File Size

    static func formatSize(_ bytes: Int64) -> String {

        let units = ["B", "KB", "MB", "GB", "TB"]

        var value = Double(bytes)

        var idx = 0

        while value >= 1024 && idx < units.count - 1 {

            value /= 1024

            idx += 1
        }

        return String(format: "%.1f %@", value, units[idx])
    }
}
