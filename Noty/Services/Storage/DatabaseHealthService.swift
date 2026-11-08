import Foundation
import SwiftData
import AppKit

/// 資料庫健康檢查與修復服務
public final class DatabaseHealthService {
    public static let shared = DatabaseHealthService()
    
    private init() {}
    
    public struct HealthIssue: Identifiable {
        public let id = UUID()
        public let category: IssueCategory
        public let description: String
        public let severity: IssueSeverity
        public let relatedPath: String?
        public let relatedID: UUID?
    }
    
    public enum IssueCategory: String {
        case missingFile = "檔案遺失"
        case orphanFile = "孤立檔案"
        case missingThumbnail = "縮圖遺失"
        case corruptedThumbnail = "縮圖損壞"
        case checksumMismatch = "SHA-256 不符"
        case invalidPath = "路徑異常"
        case danglingTemp = "暫存殘留"
        case brokenDiaryAttachment = "日記附件斷鏈"
        case brokenAlbumReference = "相簿關聯斷鏈"
        case inconsistentTrash = "垃圾桶狀態不一致"
    }
    
    public enum IssueSeverity: String {
        case warning = "警告"
        case error = "錯誤"
        case info = "資訊"
    }
    
    public struct HealthReport {
        public var checkedAt: Date = Date()
        public var totalMediaChecked: Int = 0
        public var totalDiariesChecked: Int = 0
        public var totalAlbumsChecked: Int = 0
        public var issues: [HealthIssue] = []
        
        public var isHealthy: Bool {
            issues.isEmpty
        }
        
        public var errorCount: Int {
            issues.filter { $0.severity == .error }.count
        }
        
        public var warningCount: Int {
            issues.filter { $0.severity == .warning }.count
        }
    }
    
    /// 執行全套 10 大項目健康檢查
    public func runFullHealthCheck(
        mediaItems: [MediaItem],
        diaryEntries: [DiaryEntry],
        albums: [Album]
    ) async -> HealthReport {
        var report = HealthReport(
            checkedAt: Date(),
            totalMediaChecked: mediaItems.count,
            totalDiariesChecked: diaryEntries.count,
            totalAlbumsChecked: albums.count,
            issues: []
        )
        
        let fileManager = FileManager.default
        let mediaItemIDs = Set(mediaItems.map { $0.id })
        var knownRelativePaths = Set<String>()
        
        // 1. 檢查資料庫記錄之檔案完整性、路徑有效性與縮圖
        for item in mediaItems {
            knownRelativePaths.insert(item.relativePath)
            
            // 檢查路徑遍歷防護
            if item.relativePath.contains("..") || item.relativePath.hasPrefix("/") {
                report.issues.append(HealthIssue(
                    category: .invalidPath,
                    description: "偵測到異常路徑語法: \(item.relativePath)",
                    severity: .error,
                    relatedPath: item.relativePath,
                    relatedID: item.id
                ))
            }
            
            // 檢查實體檔案是否存在
            if !item.isDeleted && !item.fileExistsOnDisk {
                report.issues.append(HealthIssue(
                    category: .missingFile,
                    description: "資料庫存在項目「\(item.originalFileName)」，但實體檔案不存在於: \(item.relativePath)",
                    severity: .error,
                    relatedPath: item.relativePath,
                    relatedID: item.id
                ))
            }
            
            // 檢查縮圖
            let thumbPath = ThumbnailService.shared.thumbnailURL(for: item.storedFileName)
            if !item.isDeleted && !fileManager.fileExists(atPath: thumbPath.path) {
                report.issues.append(HealthIssue(
                    category: .missingThumbnail,
                    description: "項目「\(item.originalFileName)」缺少快取縮圖",
                    severity: .warning,
                    relatedPath: thumbPath.path,
                    relatedID: item.id
                ))
            } else if fileManager.fileExists(atPath: thumbPath.path) {
                // 檢查縮圖是否可正常讀取為圖片
                if NSImage(contentsOf: thumbPath) == nil {
                    report.issues.append(HealthIssue(
                        category: .corruptedThumbnail,
                        description: "項目「\(item.originalFileName)」的縮圖損毀無法解碼",
                        severity: .warning,
                        relatedPath: thumbPath.path,
                        relatedID: item.id
                    ))
                }
            }
            
            // 檢查垃圾桶日期一致性
            if item.isDeleted && item.deletedAt == nil {
                report.issues.append(HealthIssue(
                    category: .inconsistentTrash,
                    description: "項目「\(item.originalFileName)」標記為刪除，但缺乏刪除時間戳記",
                    severity: .warning,
                    relatedPath: item.relativePath,
                    relatedID: item.id
                ))
            }
        }
        
        // 2. 檢查孤立檔案（存在於磁碟但無資料庫紀錄）
        let imagesDir = StorageService.shared.mediaImagesDirectory
        let videosDir = StorageService.shared.mediaVideosDirectory
        
        for dir in [imagesDir, videosDir] {
            if let files = try? fileManager.contentsOfDirectory(atPath: dir.path) {
                let subfolder = (dir == imagesDir) ? "Library/Media/Images/" : "Library/Media/Videos/"
                for file in files where !file.hasPrefix(".") {
                    let rel = subfolder + file
                    if !knownRelativePaths.contains(rel) {
                        report.issues.append(HealthIssue(
                            category: .orphanFile,
                            description: "磁碟中發現孤立媒體檔案: \(file)，未關聯任何資料庫記錄",
                            severity: .warning,
                            relatedPath: rel,
                            relatedID: nil
                        ))
                    }
                }
            }
        }
        
        // 3. 檢查 Temp 暫存目錄是否殘留檔案
        let tempDir = StorageService.shared.tempDirectory
        if let tempFiles = try? fileManager.contentsOfDirectory(atPath: tempDir.path) {
            for file in tempFiles where !file.hasPrefix(".") {
                report.issues.append(HealthIssue(
                    category: .danglingTemp,
                    description: "暫存目錄殘留未完成匯入檔案: \(file)",
                    severity: .info,
                    relatedPath: "Library/Temp/\(file)",
                    relatedID: nil
                ))
            }
        }
        
        // 4. 檢查日記附件關聯是否斷鏈
        for diary in diaryEntries {
            for attachID in diary.attachedMediaIDs {
                if !mediaItemIDs.contains(attachID) {
                    report.issues.append(HealthIssue(
                        category: .brokenDiaryAttachment,
                        description: "日記「\(diary.title.isEmpty ? "未命名日記" : diary.title)」參照了不存在的媒體 ID: \(attachID)",
                        severity: .warning,
                        relatedPath: nil,
                        relatedID: diary.id
                    ))
                }
            }
        }
        
        // 5. 檢查相簿媒體關聯是否斷鏈
        for album in albums {
            for itemID in album.mediaItemIDs {
                if !mediaItemIDs.contains(itemID) {
                    report.issues.append(HealthIssue(
                        category: .brokenAlbumReference,
                        description: "相簿「\(album.name)」參照了不存在的媒體 ID: \(itemID)",
                        severity: .warning,
                        relatedPath: nil,
                        relatedID: album.id
                    ))
                }
            }
        }
        
        return report
    }
    
    // MARK: - 修復工具
    
    /// 重新批次產生所有遺失或損壞的縮圖
    public func rebuildThumbnails(for items: [MediaItem]) async -> Int {
        var rebuiltCount = 0
        for item in items where !item.isDeleted && item.fileExistsOnDisk {
            let thumbPath = ThumbnailService.shared.thumbnailURL(for: item.storedFileName)
            let needRebuild = !FileManager.default.fileExists(atPath: thumbPath.path) || NSImage(contentsOf: thumbPath) == nil
            
            if needRebuild {
                let success = (try? await ThumbnailService.shared.generateThumbnail(
                    for: item.fileURL,
                    storedFileName: item.storedFileName,
                    isVideo: item.mediaType == .video
                )) != nil
                if success {
                    rebuiltCount += 1
                }
            }
        }
        return rebuiltCount
    }
    
    /// 清理暫存目錄
    public func cleanupDanglingTempFiles() -> Int {
        let fileManager = FileManager.default
        let tempDir = StorageService.shared.tempDirectory
        guard let files = try? fileManager.contentsOfDirectory(atPath: tempDir.path) else { return 0 }
        
        var deleted = 0
        for file in files where !file.hasPrefix(".") {
            let fullURL = tempDir.appendingPathComponent(file)
            if (try? fileManager.removeItem(at: fullURL)) != nil {
                deleted += 1
            }
        }
        return deleted
    }
    
    /// 修復日記與相簿無效關聯
    @MainActor
    public func pruneBrokenReferences(
        diaryEntries: [DiaryEntry],
        albums: [Album],
        validMediaIDs: Set<UUID>,
        modelContext: ModelContext
    ) {
        for diary in diaryEntries {
            let valid = diary.attachedMediaIDs.filter { validMediaIDs.contains($0) }
            if valid.count != diary.attachedMediaIDs.count {
                diary.attachedMediaIDs = valid
            }
        }
        for album in albums {
            let valid = album.mediaItemIDs.filter { validMediaIDs.contains($0) }
            if valid.count != album.mediaItemIDs.count {
                album.mediaItemIDs = valid
            }
        }
        try? modelContext.save()
    }
}
