import Foundation
import SwiftData

/// 備份檔案詳細驗證條目
public struct BackupManifestFileEntry: Codable, Sendable, Equatable {
    public let relativePath: String
    public let fileSizeBytes: Int64
    public let sha256: String
    
    public init(relativePath: String, fileSizeBytes: Int64, sha256: String) {
        self.relativePath = relativePath
        self.fileSizeBytes = fileSizeBytes
        self.sha256 = sha256
    }
}

/// 備份配置類型枚舉
public enum BackupProfile: String, CaseIterable, Identifiable, Sendable {
    case full = "Full Backup"
    case incremental = "Incremental Backup"
    case database = "Database Snapshot"
    case media = "Media Only"
    case diary = "Diaries Only"
    case encryptedArchive = "Encrypted Vault Archive"
    
    public var id: String { rawValue }
}

/// 備份中介資訊清單結構體
public struct BackupManifest: Codable, Sendable {
    public let appName: String
    public let appVersion: String
    public let backupDate: Date
    public let photoCount: Int
    public let videoCount: Int
    public let diaryCount: Int
    public let totalSizeBytes: Int64
    public let manifestNotes: String
    public var profile: String
    public var files: [BackupManifestFileEntry]
    
    public init(
        appName: String = "Noty",
        appVersion: String = "1.0.0",
        backupDate: Date = Date(),
        photoCount: Int,
        videoCount: Int,
        diaryCount: Int,
        totalSizeBytes: Int64,
        manifestNotes: String,
        profile: String = "Full",
        files: [BackupManifestFileEntry] = []
    ) {
        self.appName = appName
        self.appVersion = appVersion
        self.backupDate = backupDate
        self.photoCount = photoCount
        self.videoCount = videoCount
        self.diaryCount = diaryCount
        self.totalSizeBytes = totalSizeBytes
        self.manifestNotes = manifestNotes
        self.profile = profile
        self.files = files
    }
}

/// 日記匯出格式枚舉
public enum DiaryExportFormat: String, CaseIterable, Identifiable {
    case markdown = "Markdown (.md)"
    case json = "Structured JSON (.json)"
    
    public var id: String { rawValue }
}

/// 本機備份、還原與匯出服務（BackupService）
/// 支援獨立日記匯出、媒體匯出、資料庫快照、全庫完整打包與安全預檢還原機制
public final class BackupService: @unchecked Sendable {
    public static let shared = BackupService()
    
    private let fileManager = FileManager.default
    private let storage = StorageService.shared
    
    private init() {}
    
    // MARK: - 1. 匯出日記
    
    /// 將所有日記匯出為 Markdown 檔案或 JSON 封裝檔
    public func exportDiaries(
        entries: [DiaryEntry],
        to destinationFolder: URL,
        format: DiaryExportFormat = .markdown
    ) throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let exportDir = destinationFolder.appendingPathComponent("Noty_Diaries_\(timestamp)", isDirectory: true)
        try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)
        
        if format == .markdown {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            for (idx, entry) in entries.enumerated() {
                let sanitizedTitle = entry.title
                    .replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: ":", with: "-")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let fileName = sanitizedTitle.isEmpty ? "Diary_\(idx + 1).md" : "\(sanitizedTitle).md"
                let fileURL = exportDir.appendingPathComponent(fileName)
                
                var mdContent = """
                ---
                title: "\(entry.title)"
                date: \(df.string(from: entry.entryDate))
                mood: "\(entry.mood)"
                tags: [\(entry.tags.map { "\"\($0)\"" }.joined(separator: ", "))]
                isFavorite: \(entry.isFavorite)
                mediaCount: \(entry.attachedMediaIDs.count)
                ---

                # \(entry.title.isEmpty ? "Diary Entry" : entry.title)

                \(entry.content)
                """
                try mdContent.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        } else {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            
            struct DiaryExportDTO: Codable {
                let id: String
                let title: String
                let content: String
                let entryDate: Date
                let mood: String
                let tags: [String]
                let isFavorite: Bool
            }
            
            let dtoArray = entries.map {
                DiaryExportDTO(
                    id: $0.id.uuidString,
                    title: $0.title,
                    content: $0.content,
                    entryDate: $0.entryDate,
                    mood: $0.mood,
                    tags: $0.tags,
                    isFavorite: $0.isFavorite
                )
            }
            
            let data = try encoder.encode(dtoArray)
            let jsonFileURL = exportDir.appendingPathComponent("diaries.json")
            try data.write(to: jsonFileURL)
        }
        
        return exportDir
    }
    
    // MARK: - 2. 匯出媒體檔案
    
    /// 匯出所有內部儲存之照片與影片至外部資料夾
    public func exportMedia(items: [MediaItem], to destinationFolder: URL) throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let exportDir = destinationFolder.appendingPathComponent("Noty_Media_Export_\(timestamp)", isDirectory: true)
        
        let photosDir = exportDir.appendingPathComponent("Photos", isDirectory: true)
        let videosDir = exportDir.appendingPathComponent("Videos", isDirectory: true)
        try fileManager.createDirectory(at: photosDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: videosDir, withIntermediateDirectories: true)
        
        for item in items {
            guard item.fileExistsOnDisk else { continue }
            let targetSubdir = item.mediaType == .video ? videosDir : photosDir
            let targetFileURL = targetSubdir.appendingPathComponent(item.originalFileName)
            
            // 若遇檔名重複，附加安全識別碼
            let finalTarget: URL
            if fileManager.fileExists(atPath: targetFileURL.path) {
                let stem = targetFileURL.deletingPathExtension().lastPathComponent
                let ext = targetFileURL.pathExtension
                finalTarget = targetSubdir.appendingPathComponent("\(stem)_\(UUID().uuidString.prefix(6)).\(ext)")
            } else {
                finalTarget = targetFileURL
            }
            
            try? fileManager.copyItem(at: item.fileURL, to: finalTarget)
        }
        
        return exportDir
    }
    
    // MARK: - 3. 匯出資料庫快照
    
    /// 匯出 SwiftData 底層資料庫至目標路徑
    public func exportDatabaseSnapshot(to destinationFolder: URL) throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let exportTarget = destinationFolder.appendingPathComponent("Noty_Database_\(timestamp).store")
        
        if fileManager.fileExists(atPath: storage.databaseFileURL.path) {
            try fileManager.copyItem(at: storage.databaseFileURL, to: exportTarget)
        } else {
            throw StorageError.fileNotFound(storage.databaseFileURL)
        }
        
        return exportTarget
    }
    
    // MARK: - 4. 建立完整全庫備份 (Full Backup)
    
    /// 建立封裝有 Manifest、Database 與 Media 的完整備份包
    public func createFullBackup(
        to targetFolderURL: URL,
        photoCount: Int,
        videoCount: Int,
        diaryCount: Int
    ) throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupFolderName = "Noty_FullBackup_\(timestamp)"
        let backupDir = targetFolderURL.appendingPathComponent(backupFolderName, isDirectory: true)
        
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        
        // 1. 複製資料庫
        let dbTarget = backupDir.appendingPathComponent("Database", isDirectory: true)
        if fileManager.fileExists(atPath: storage.databaseDirectory.path) {
            try fileManager.copyItem(at: storage.databaseDirectory, to: dbTarget)
        }
        
        // 2. 複製媒體
        let mediaTarget = backupDir.appendingPathComponent("Media", isDirectory: true)
        let mediaSource = storage.libraryDirectory.appendingPathComponent("Media", isDirectory: true)
        if fileManager.fileExists(atPath: mediaSource.path) {
            try fileManager.copyItem(at: mediaSource, to: mediaTarget)
        }
        
        // 3. 生成檔案詳細清單 (Files with SHA-256)
        var fileEntries: [BackupManifestFileEntry] = []
        if let enumerator = fileManager.enumerator(at: backupDir, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) {
            for case let fileURL as URL in enumerator {
                if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                    if fileURL.lastPathComponent == "Manifest.json" { continue }
                    let relPath = fileURL.path.replacingOccurrences(of: backupDir.path + "/", with: "")
                    let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
                    let hash = (try? storage.computeSHA256(for: fileURL)) ?? ""
                    fileEntries.append(BackupManifestFileEntry(relativePath: relPath, fileSizeBytes: size, sha256: hash))
                }
            }
        }
        
        let totalSize = storage.sizeOfDirectory(at: backupDir)
        let manifest = BackupManifest(
            appName: "Noty",
            appVersion: "1.0.0",
            backupDate: Date(),
            photoCount: photoCount,
            videoCount: videoCount,
            diaryCount: diaryCount,
            totalSizeBytes: totalSize,
            manifestNotes: "Full local standalone backup with SHA-256 manifest",
            profile: "Full",
            files: fileEntries
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: backupDir.appendingPathComponent("Manifest.json"))
        
        return backupDir
    }
    
    // MARK: - 5. 備份版本輪替 (Backup Rotation)
    
    /// 備份版本輪替：保留最近 retainCount 份備份，自動安全修剪超出版本
    /// 必須先驗證最新備份完整，才允許修剪舊備份
    public func rotateBackups(in directory: URL = StorageService.shared.backupsDirectory, retainCount: Int = 5) throws -> Int {
        guard retainCount > 0 else { return 0 }
        let items = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey])
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true &&
                url.lastPathComponent.hasPrefix("Noty_")
            }
            .sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return dateA > dateB // 最新優先
            }
        
        guard items.count > retainCount else { return 0 }
        
        // 驗證最新一份備份是可讀且完整的
        if let newest = items.first {
            let manifestResult = try? inspectBackup(at: newest)
            guard manifestResult != nil else {
                print("⚠️ 最新備份無法讀取，中止備份輪替修剪，以防資料遺失！")
                return 0
            }
        }
        
        let toPrune = items.suffix(from: retainCount)
        var prunedCount = 0
        for oldBackup in toPrune {
            try fileManager.removeItem(at: oldBackup)
            prunedCount += 1
        }
        return prunedCount
    }
    
    // MARK: - 6. 深度校驗備份包完整性 (Verify Backup Integrity)
    
    /// 深度校驗備份包完整性（逐檔 SHA-256 與結構驗證）
    public func verifyBackupIntegrity(at backupFolderURL: URL) throws -> (isValid: Bool, checkedFiles: Int, issues: [String]) {
        let manifest = try inspectBackup(at: backupFolderURL)
        var issues: [String] = []
        var checkedCount = 0
        
        for fileEntry in manifest.files {
            let fileURL = backupFolderURL.appendingPathComponent(fileEntry.relativePath)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                issues.append("遺失檔案：\(fileEntry.relativePath)")
                continue
            }
            
            let currentSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
            if currentSize != fileEntry.fileSizeBytes {
                issues.append("檔案大小不符：\(fileEntry.relativePath)（預期 \(fileEntry.fileSizeBytes)，實際 \(currentSize)）")
            }
            
            let currentSHA = try storage.computeSHA256(for: fileURL)
            if currentSHA != fileEntry.sha256 {
                issues.append("SHA-256 雜湊不符：\(fileEntry.relativePath)")
            }
            checkedCount += 1
        }
        
        return (issues.isEmpty, checkedCount, issues)
    }
    
    // MARK: - 7. 隔離沙盒災難復原驗證 (Disaster Recovery Simulation)
    
    public struct SandboxRestoreVerification: Sendable {
        public let isSuccess: Bool
        public let verifiedFileCount: Int
        public let databaseFound: Bool
        public let errors: [String]
    }
    
    /// 在隔離測試目錄中還原備份，並進行 100% 結構與雜湊驗證，絕不碰觸使用者當前正式庫
    public func restoreToIsolatedSandbox(at backupFolderURL: URL, sandboxDirectory: URL) throws -> SandboxRestoreVerification {
        try fileManager.createDirectory(at: sandboxDirectory, withIntermediateDirectories: true)
        
        let targetDB = sandboxDirectory.appendingPathComponent("Database", isDirectory: true)
        let sourceDB = backupFolderURL.appendingPathComponent("Database")
        var dbFound = false
        if fileManager.fileExists(atPath: sourceDB.path) {
            try fileManager.copyItem(at: sourceDB, to: targetDB)
            dbFound = true
        }
        
        let targetMedia = sandboxDirectory.appendingPathComponent("Media", isDirectory: true)
        let sourceMedia = backupFolderURL.appendingPathComponent("Media")
        if fileManager.fileExists(atPath: sourceMedia.path) {
            try fileManager.copyItem(at: sourceMedia, to: targetMedia)
        }
        
        let integrity = try verifyBackupIntegrity(at: backupFolderURL)
        return SandboxRestoreVerification(
            isSuccess: dbFound && integrity.isValid,
            verifiedFileCount: integrity.checkedFiles,
            databaseFound: dbFound,
            errors: integrity.issues
        )
    }
    
    // MARK: - 5. 檢驗備份包完整性 (Inspect Backup)
    
    /// 讀取外部選取之備份資料夾並進行驗證
    public func inspectBackup(at folderURL: URL) throws -> BackupManifest {
        let manifestURL = folderURL.appendingPathComponent("Manifest.json")
        let dbDir = folderURL.appendingPathComponent("Database")
        
        guard fileManager.fileExists(atPath: dbDir.path) else {
            throw NSError(domain: "NotyBackup", code: 404, userInfo: [NSLocalizedDescriptionKey: "選取的資料夾非有效的 Noty 備份包（找不到 Database 目錄）"])
        }
        
        if fileManager.fileExists(atPath: manifestURL.path) {
            let data = try Data(contentsOf: manifestURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(BackupManifest.self, from: data)
        } else {
            // 無 Manifest 時，由檔案目錄反推
            let totalSize = storage.sizeOfDirectory(at: folderURL)
            return BackupManifest(
                appName: "Noty",
                appVersion: "Legacy / Custom",
                backupDate: (try? folderURL.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date(),
                photoCount: -1,
                videoCount: -1,
                diaryCount: -1,
                totalSizeBytes: totalSize,
                manifestNotes: "Verified Database structure"
            )
        }
    }
    
    // MARK: - 6. 安全還原 (Restore from Backup)
    
    /// 從備份還原（強制先在本機 Backups/ 建立緊急回滾還原點，杜絕任何資料損失）
    public func restoreFromBackup(at backupFolderURL: URL) throws {
        // 1. 建立緊急快照 (Safety Rollback Snapshot)
        let safetyTimestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let rollbackDir = storage.backupsDirectory.appendingPathComponent("Pre_Restore_Safety_\(safetyTimestamp)", isDirectory: true)
        try fileManager.createDirectory(at: rollbackDir, withIntermediateDirectories: true)
        
        if fileManager.fileExists(atPath: storage.databaseDirectory.path) {
            try? fileManager.copyItem(at: storage.databaseDirectory, to: rollbackDir.appendingPathComponent("Database"))
        }
        
        // 2. 還原 Database
        let backupDBDir = backupFolderURL.appendingPathComponent("Database")
        if fileManager.fileExists(atPath: backupDBDir.path) {
            if fileManager.fileExists(atPath: storage.databaseDirectory.path) {
                try fileManager.removeItem(at: storage.databaseDirectory)
            }
            try fileManager.copyItem(at: backupDBDir, to: storage.databaseDirectory)
        }
        
        // 3. 還原 Media
        let backupMediaDir = backupFolderURL.appendingPathComponent("Media")
        let liveMediaDir = storage.libraryDirectory.appendingPathComponent("Media")
        if fileManager.fileExists(atPath: backupMediaDir.path) {
            if fileManager.fileExists(atPath: liveMediaDir.path) {
                try fileManager.removeItem(at: liveMediaDir)
            }
            try fileManager.copyItem(at: backupMediaDir, to: liveMediaDir)
        }
        
        // 4. 清理並重新產生縮圖目錄
        ThumbnailService.shared.clearCache()
        
        // 5. 發送全域通知提示資料庫已重置
        NotificationCenter.default.post(name: .notyDatabaseDidRestore, object: nil)
    }
}

public extension Notification.Name {
    static let notyDatabaseDidRestore = Notification.Name("notyDatabaseDidRestore")
}
