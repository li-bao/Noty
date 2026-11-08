import Foundation
import CryptoKit
import ImageIO
import AVFoundation

/// 儲存服務錯誤類型
public enum StorageError: LocalizedError {
    case fileNotFound(URL)
    case unreadableSource(URL)
    case copyFailed(String)
    case duplicateDetected(String)
    case directoryCreationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "找不到指定的檔案：\(url.path)"
        case .unreadableSource(let url):
            return "無法讀取原始檔案（可能缺乏權限）：\(url.path)"
        case .copyFailed(let reason):
            return "複製檔案至沙盒庫失敗：\(reason)"
        case .duplicateDetected(let hash):
            return "偵測到完全重複的檔案（SHA-256: \(hash)）"
        case .directoryCreationFailed(let msg):
            return "建立資料夾目錄失敗：\(msg)"
        }
    }
}

/// 匯入結果結構體
public struct MediaImportResult: Sendable {
    public let originalFileName: String
    public let storedFileName: String
    public let relativePath: String
    public let absoluteURL: URL
    public let mediaTypeRaw: String
    public let fileFormat: String
    public let fileSizeBytes: Int64
    public let sha256Hash: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let durationSeconds: Double
    public let capturedAt: Date
}

/// Noty 核心檔案儲存管理服務
/// 管理 Application Support/Noty 結構樹、非破壞性儲存、雜湊比對與安全清理
public final class StorageService: @unchecked Sendable {
    public static let shared = StorageService()
    
    private let fileManager = FileManager.default
    
    // MARK: - 目錄結構定義
    public let rootDirectory: URL
    public let databaseDirectory: URL
    public let databaseFileURL: URL
    
    public let libraryDirectory: URL
    public let mediaImagesDirectory: URL
    public let mediaVideosDirectory: URL
    public let thumbnailsDirectory: URL
    public let tempDirectory: URL
    public let exportsDirectory: URL
    public let backupsDirectory: URL
    
    private init() {
        // ~/Library/Application Support/Noty/
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("無法取得使用者 Application Support 目錄")
        }
        
        let notyRoot = appSupport.appendingPathComponent("Noty", isDirectory: true)
        self.rootDirectory = notyRoot
        
        // 1. Database/Noty.store
        let dbDir = notyRoot.appendingPathComponent("Database", isDirectory: true)
        self.databaseDirectory = dbDir
        self.databaseFileURL = dbDir.appendingPathComponent("Noty.store")
        
        // 2. Library/
        let libDir = notyRoot.appendingPathComponent("Library", isDirectory: true)
        self.libraryDirectory = libDir
        
        // 2.1 Library/Media/Images & Videos
        let mediaDir = libDir.appendingPathComponent("Media", isDirectory: true)
        self.mediaImagesDirectory = mediaDir.appendingPathComponent("Images", isDirectory: true)
        self.mediaVideosDirectory = mediaDir.appendingPathComponent("Videos", isDirectory: true)
        
        // 2.2 Library/Thumbnails
        self.thumbnailsDirectory = libDir.appendingPathComponent("Thumbnails", isDirectory: true)
        
        // 2.3 Library/Temp
        self.tempDirectory = libDir.appendingPathComponent("Temp", isDirectory: true)
        
        // 2.4 Library/Exports
        self.exportsDirectory = libDir.appendingPathComponent("Exports", isDirectory: true)
        
        // 2.5 Library/Backups
        self.backupsDirectory = libDir.appendingPathComponent("Backups", isDirectory: true)
        
        ensureDirectoriesExist()
        createGlobalSymlinkIfPossible()
    }
    
    /// 若處於沙盒中，於一般 Application Support 建立便捷符號連結供使用者快速終端機存取
    private func createGlobalSymlinkIfPossible() {
        let homeDir = URL(fileURLWithPath: NSHomeDirectory())
        let standardAppSupport = homeDir.appendingPathComponent("Library/Application Support", isDirectory: true)
        let convenientLink = standardAppSupport.appendingPathComponent("Noty", isDirectory: true)
        
        if convenientLink.path != rootDirectory.path && !fileManager.fileExists(atPath: convenientLink.path) {
            try? fileManager.createSymbolicLink(at: convenientLink, withDestinationURL: rootDirectory)
        }
    }
    
    /// 初始化並確保所有必要目錄存在（安全沿用既有資料，不覆蓋舊資料）
    public func ensureDirectoriesExist() {
        let directories = [
            rootDirectory,
            databaseDirectory,
            libraryDirectory,
            mediaImagesDirectory,
            mediaVideosDirectory,
            thumbnailsDirectory,
            tempDirectory,
            exportsDirectory,
            backupsDirectory
        ]
        
        for dir in directories {
            if !fileManager.fileExists(atPath: dir.path) {
                do {
                    try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("⚠️ 建立目錄失敗: \(dir.path), 原因: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - 相對路徑與絕對路徑轉換
    
    /// 將相對路徑轉為系統絕對路徑（例如：Library/Media/Images/xxx.jpg -> file:///.../Noty/Library/Media/Images/xxx.jpg）
    public func absoluteURL(for relativePath: String) -> URL {
        return rootDirectory.appendingPathComponent(relativePath)
    }
    
    /// 檢查相對路徑檔案是否存在於本機硬碟
    public func fileExists(for relativePath: String) -> Bool {
        let absURL = absoluteURL(for: relativePath)
        return fileManager.fileExists(atPath: absURL.path)
    }
    
    // MARK: - SHA-256 雜湊計算
    
    /// 計算本機檔案的 SHA-256 雜湊字串
    public func computeSHA256(for fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 1024 * 1024) // 1MB 串流讀取，低記憶體消耗
            if chunk.isEmpty { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - 媒體安全匯入（非破壞性複製）
    
    /// 從來源 URL 匯入媒體（計算雜湊、解析元資料、複製至沙盒庫，絕不刪除來源）
    public func importMedia(from sourceURL: URL) throws -> MediaImportResult {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw StorageError.fileNotFound(sourceURL)
        }
        
        // 1. 計算 SHA-256 雜湊
        let sha256 = try computeSHA256(for: sourceURL)
        
        // 2. 獲取檔案資訊
        let attr = try fileManager.attributesOfItem(atPath: sourceURL.path)
        let fileSize = (attr[.size] as? NSNumber)?.int64Value ?? 0
        let originalFileName = sourceURL.lastPathComponent
        let fileExtension = sourceURL.pathExtension.lowercased()
        
        let isVideo = ["mp4", "mov", "m4v", "avi", "mkv"].contains(fileExtension)
        let mediaTypeRaw = isVideo ? "video" : "image"
        
        // 3. 決定目標目錄與唯一定名
        let targetDirectory = isVideo ? mediaVideosDirectory : mediaImagesDirectory
        let uniqueID = UUID().uuidString.prefix(8)
        let hashPrefix = String(sha256.prefix(8))
        let storedFileName = "\(hashPrefix)_\(uniqueID).\(fileExtension.isEmpty ? "bin" : fileExtension)"
        let destinationURL = targetDirectory.appendingPathComponent(storedFileName)
        
        // 4. 複製檔案（非破壞性）
        if !fileManager.fileExists(atPath: destinationURL.path) {
            do {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            } catch {
                throw StorageError.copyFailed(error.localizedDescription)
            }
        }
        
        // 5. 解析元資料（圖片寬高、拍攝日期、影片長度）
        var pixelWidth = 0
        var pixelHeight = 0
        var durationSeconds: Double = 0.0
        var capturedDate = (attr[.creationDate] as? Date) ?? Date()
        
        if isVideo {
            let asset = AVURLAsset(url: destinationURL)
            let duration = asset.duration
            if duration.timescale > 0 {
                durationSeconds = Double(duration.value) / Double(duration.timescale)
            }
            if let track = asset.tracks(withMediaType: .video).first {
                let size = track.naturalSize.applying(track.preferredTransform)
                pixelWidth = Int(abs(size.width))
                pixelHeight = Int(abs(size.height))
            }
        } else {
            if let imageSource = CGImageSourceCreateWithURL(destinationURL as CFURL, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
                pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
                pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
                
                // 嘗試自 EXIF 解析拍攝時間
                if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
                   let dateStr = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                    let df = DateFormatter()
                    df.dateFormat = "yyyy:MM:dd HH:mm:ss"
                    if let d = df.date(from: dateStr) {
                        capturedDate = d
                    }
                }
            }
        }
        
        // 6. 計算相對路徑（相對於 rootDirectory）
        let relativePath: String
        if isVideo {
            relativePath = "Library/Media/Videos/\(storedFileName)"
        } else {
            relativePath = "Library/Media/Images/\(storedFileName)"
        }
        
        return MediaImportResult(
            originalFileName: originalFileName,
            storedFileName: storedFileName,
            relativePath: relativePath,
            absoluteURL: destinationURL,
            mediaTypeRaw: mediaTypeRaw,
            fileFormat: fileExtension,
            fileSizeBytes: fileSize,
            sha256Hash: sha256,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            durationSeconds: durationSeconds,
            capturedAt: capturedDate
        )
    }
    
    // MARK: - 垃圾桶與安全實體清理
    
    /// 永久刪除指定的本機檔案（僅在清空垃圾桶或確認刪除時由使用者調用）
    public func permanentlyDeleteFile(at relativePath: String) {
        let fileURL = absoluteURL(for: relativePath)
        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    // MARK: - 容量與指標統計
    
    /// 計算目錄容量大小
    public func sizeOfDirectory(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = resourceValues.fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }
    
    /// 取得 Noty 總容量統計結構
    public func storageBreakdown() -> (totalBytes: Int64, mediaBytes: Int64, databaseBytes: Int64, formattedTotal: String) {
        let total = sizeOfDirectory(at: rootDirectory)
        let imagesSize = sizeOfDirectory(at: mediaImagesDirectory)
        let videosSize = sizeOfDirectory(at: mediaVideosDirectory)
        let mediaBytes = imagesSize + videosSize
        let dbBytes = sizeOfDirectory(at: databaseDirectory)
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        let formatted = formatter.string(fromByteCount: total)
        
        return (total, mediaBytes, dbBytes, formatted)
    }
    
    // MARK: - 匯出與備份
    
    /// 匯出全庫備份至指定資料夾
    public func exportBackup(to targetFolderURL: URL) throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupFolderName = "Noty_Backup_\(timestamp)"
        let backupTarget = targetFolderURL.appendingPathComponent(backupFolderName, isDirectory: true)
        
        try fileManager.createDirectory(at: backupTarget, withIntermediateDirectories: true)
        
        // 複製 Database
        let dbDest = backupTarget.appendingPathComponent("Database", isDirectory: true)
        if fileManager.fileExists(atPath: databaseDirectory.path) {
            try fileManager.copyItem(at: databaseDirectory, to: dbDest)
        }
        
        // 複製 Media
        let mediaDest = backupTarget.appendingPathComponent("Media", isDirectory: true)
        let mediaSource = libraryDirectory.appendingPathComponent("Media", isDirectory: true)
        if fileManager.fileExists(atPath: mediaSource.path) {
            try fileManager.copyItem(at: mediaSource, to: mediaDest)
        }
        
        return backupTarget
    }
    
    // MARK: - Phase 9.875 儲存健康指標與磁碟監控
    
    public struct StorageBreakdown: Sendable {
        public let totalBytes: Int64
        public let databaseBytes: Int64
        public let photosBytes: Int64
        public let videosBytes: Int64
        public let thumbnailsBytes: Int64
        public let backupsBytes: Int64
        public let tempBytes: Int64
        public let freeDiskBytes: Int64
    }
    
    public func getStorageBreakdown() -> StorageBreakdown {
        let total = sizeOfDirectory(at: rootDirectory)
        let db = sizeOfDirectory(at: databaseDirectory)
        let photos = sizeOfDirectory(at: mediaImagesDirectory)
        let videos = sizeOfDirectory(at: mediaVideosDirectory)
        let thumbs = sizeOfDirectory(at: thumbnailsDirectory)
        let backups = sizeOfDirectory(at: backupsDirectory)
        let temp = sizeOfDirectory(at: tempDirectory)
        let freeDisk = getAvailableDiskSpace()
        
        return StorageBreakdown(
            totalBytes: total,
            databaseBytes: db,
            photosBytes: photos,
            videosBytes: videos,
            thumbnailsBytes: thumbs,
            backupsBytes: backups,
            tempBytes: temp,
            freeDiskBytes: freeDisk
        )
    }
    
    /// 取得目前系統剩餘可用磁碟空間位元組數
    public func getAvailableDiskSpace() -> Int64 {
        do {
            let values = try rootDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
            if let important = values.volumeAvailableCapacityForImportantUsage {
                return important
            }
            if let available = values.volumeAvailableCapacity {
                return Int64(available)
            }
        } catch {
            print("無法讀取磁碟空間: \(error)")
        }
        return 10 * 1024 * 1024 * 1024 // 預設 10 GB 容錯
    }
    
    /// 重新關聯遺失媒體檔案（Relink Media File）
    public func relinkMediaItem(_ item: MediaItem, to newSourceURL: URL) throws {
        let destURL = absoluteURL(for: item.relativePath)
        let dir = destURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destURL.path) {
            try fileManager.removeItem(at: destURL)
        }
        try fileManager.copyItem(at: newSourceURL, to: destURL)
        item.sha256Hash = try computeSHA256(for: destURL)
        if let attrs = try? fileManager.attributesOfItem(atPath: destURL.path),
           let size = attrs[.size] as? Int64 {
            item.fileSizeBytes = size
        }
        item.isMissing = false
    }
    
    /// 清理孤立暫存檔案
    public func cleanOrphanTempFiles() -> (cleanedCount: Int, reclaimedBytes: Int64) {
        var count = 0
        var bytes: Int64 = 0
        guard let files = try? fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return (0, 0)
        }
        for file in files {
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
            do {
                try fileManager.removeItem(at: file)
                count += 1
                bytes += size
            } catch {
                print("無法刪除暫存檔案 \(file.lastPathComponent): \(error)")
            }
        }
        return (count, bytes)
    }
}
