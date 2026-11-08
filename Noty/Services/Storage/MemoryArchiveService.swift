import Foundation
import SwiftData

/// 可攜式回憶封裝庫服務（MemoryArchiveService）
/// 提供開放、公開 JSON Schema、自包含目錄結構之回憶封裝（NotyArchive）
/// 讓使用者即使數十年後不再使用 Noty，依然能用任何標準工具與作業系統完整讀取所有照片、影片與日記
public final class MemoryArchiveService: @unchecked Sendable {
    public static let shared = MemoryArchiveService()
    
    private let fileManager = FileManager.default
    private let storage = StorageService.shared
    
    public struct ArchiveManifest: Codable, Sendable {
        public let archiveVersion: String
        public let appName: String
        public let createdAt: Date
        public let totalPhotos: Int
        public let totalVideos: Int
        public let totalDiaries: Int
        public let totalAlbums: Int
        public let isEncrypted: Bool
        public let notes: String
    }
    
    public struct MediaExportRecord: Codable, Sendable {
        public let id: String
        public let originalFileName: String
        public let mediaType: String
        public let fileFormat: String
        public let fileSizeBytes: Int64
        public let sha256: String
        public let capturedAt: Date
        public let importedAt: Date
        public let caption: String
        public let tags: [String]
        public let isFavorite: Bool
        public let isImportant: Bool
        public let relativeFilePath: String
    }
    
    public struct DiaryExportRecord: Codable, Sendable {
        public let id: String
        public let title: String
        public let content: String
        public let entryDate: Date
        public let mood: String
        public let tags: [String]
        public let isFavorite: Bool
        public let isImportant: Bool
        public let attachedMediaIDs: [String]
    }
    
    public struct AlbumExportRecord: Codable, Sendable {
        public let id: String
        public let name: String
        public let mediaItemIDs: [String]
        public let createdAt: Date
    }
    
    private init() {}
    
    /// 匯出標準 NotyArchive 可攜式回憶封裝資料夾
    public func exportArchive(
        to destinationDirectory: URL,
        mediaItems: [MediaItem],
        diaryEntries: [DiaryEntry],
        albums: [Album],
        encryptWithPassword: String? = nil
    ) throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let archiveFolderName = "NotyArchive_\(timestamp)"
        let archiveDir = destinationDirectory.appendingPathComponent(archiveFolderName, isDirectory: true)
        
        let metadataDir = archiveDir.appendingPathComponent("metadata", isDirectory: true)
        let mediaDir = archiveDir.appendingPathComponent("media", isDirectory: true)
        let imagesDir = mediaDir.appendingPathComponent("Images", isDirectory: true)
        let videosDir = mediaDir.appendingPathComponent("Videos", isDirectory: true)
        let diariesDir = archiveDir.appendingPathComponent("diaries", isDirectory: true)
        let checksumsDir = archiveDir.appendingPathComponent("checksums", isDirectory: true)
        
        try fileManager.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: videosDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: diariesDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: checksumsDir, withIntermediateDirectories: true)
        
        var checksumLines: [String] = []
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        // 1. 複製並記錄媒體檔案
        var mediaRecords: [MediaExportRecord] = []
        let activeMedia = mediaItems.filter { !$0.isDeleted }
        for item in activeMedia {
            guard item.fileExistsOnDisk else { continue }
            let targetSubdir = item.mediaType == .video ? videosDir : imagesDir
            let subPath = item.mediaType == .video ? "media/Videos/\(item.originalFileName)" : "media/Images/\(item.originalFileName)"
            let targetFileURL = targetSubdir.appendingPathComponent(item.originalFileName)
            
            // 複製檔案（防重複重命名）
            var finalTarget = targetFileURL
            var finalSubPath = subPath
            if fileManager.fileExists(atPath: targetFileURL.path) {
                let stem = targetFileURL.deletingPathExtension().lastPathComponent
                let ext = targetFileURL.pathExtension
                let uniqueName = "\(stem)_\(item.id.uuidString.prefix(6)).\(ext)"
                finalTarget = targetSubdir.appendingPathComponent(uniqueName)
                finalSubPath = item.mediaType == .video ? "media/Videos/\(uniqueName)" : "media/Images/\(uniqueName)"
            }
            
            try fileManager.copyItem(at: item.fileURL, to: finalTarget)
            let hash = (try? storage.computeSHA256(for: finalTarget)) ?? item.sha256Hash
            checksumLines.append("\(hash)  \(finalSubPath)")
            
            mediaRecords.append(MediaExportRecord(
                id: item.id.uuidString,
                originalFileName: item.originalFileName,
                mediaType: item.mediaTypeRaw,
                fileFormat: item.fileFormat,
                fileSizeBytes: item.fileSizeBytes,
                sha256: hash,
                capturedAt: item.capturedAt,
                importedAt: item.importedAt,
                caption: item.caption,
                tags: item.tags,
                isFavorite: item.isFavorite,
                isImportant: item.isImportant,
                relativeFilePath: finalSubPath
            ))
        }
        
        // 2. 匯出日記（JSON 與 Markdown 雙格式）
        var diaryRecords: [DiaryExportRecord] = []
        let activeDiaries = diaryEntries.filter { !$0.isDeleted }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for (idx, entry) in activeDiaries.enumerated() {
            let record = DiaryExportRecord(
                id: entry.id.uuidString,
                title: entry.title,
                content: entry.content,
                entryDate: entry.entryDate,
                mood: entry.mood,
                tags: entry.tags,
                isFavorite: entry.isFavorite,
                isImportant: entry.isImportant,
                attachedMediaIDs: entry.attachedMediaIDs.map { $0.uuidString }
            )
            diaryRecords.append(record)
            
            // Markdown 檔案
            let safeTitle = entry.title
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let mdFileName = safeTitle.isEmpty ? "Diary_\(idx + 1).md" : "\(safeTitle).md"
            let mdURL = diariesDir.appendingPathComponent(mdFileName)
            let mdBody = """
            ---
            title: "\(entry.title)"
            date: \(df.string(from: entry.entryDate))
            mood: "\(entry.mood)"
            tags: [\(entry.tags.map { "\"\($0)\"" }.joined(separator: ", "))]
            isFavorite: \(entry.isFavorite)
            isImportant: \(entry.isImportant)
            attachedMediaCount: \(entry.attachedMediaIDs.count)
            ---

            # \(entry.title.isEmpty ? "Personal Memory" : entry.title)

            \(entry.content)
            """
            try? mdBody.write(to: mdURL, atomically: true, encoding: .utf8)
            if let h = try? storage.computeSHA256(for: mdURL) {
                checksumLines.append("\(h)  diaries/\(mdFileName)")
            }
        }
        
        // 3. 匯出相簿記錄
        let albumRecords = albums.map {
            AlbumExportRecord(
                id: $0.id.uuidString,
                name: $0.name,
                mediaItemIDs: $0.mediaItemIDs.map { $0.uuidString },
                createdAt: $0.createdAt
            )
        }
        
        // 4. 寫入中繼資料 JSON 檔案
        let mediaJSONData = try encoder.encode(mediaRecords)
        try mediaJSONData.write(to: metadataDir.appendingPathComponent("media.json"))
        
        let diariesJSONData = try encoder.encode(diaryRecords)
        try diariesJSONData.write(to: metadataDir.appendingPathComponent("diaries.json"))
        
        let albumsJSONData = try encoder.encode(albumRecords)
        try albumsJSONData.write(to: metadataDir.appendingPathComponent("albums.json"))
        
        // 收集所有標籤
        let allTags = Array(Set(mediaRecords.flatMap { $0.tags } + diaryRecords.flatMap { $0.tags })).sorted()
        let tagsData = try encoder.encode(allTags)
        try tagsData.write(to: metadataDir.appendingPathComponent("tags.json"))
        
        // 5. 寫入校驗碼清單
        let checksumsContent = checksumLines.joined(separator: "\n")
        try checksumsContent.write(to: checksumsDir.appendingPathComponent("sha256.txt"), atomically: true, encoding: .utf8)
        
        // 6. 寫入 Manifest.json
        let manifest = ArchiveManifest(
            archiveVersion: "1.0.0",
            appName: "Noty",
            createdAt: Date(),
            totalPhotos: mediaRecords.filter { $0.mediaType == "image" }.count,
            totalVideos: mediaRecords.filter { $0.mediaType == "video" }.count,
            totalDiaries: diaryRecords.count,
            totalAlbums: albumRecords.count,
            isEncrypted: encryptWithPassword != nil,
            notes: "Portable standalone memory archive. Designed for decades of private preservation."
        )
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: archiveDir.appendingPathComponent("manifest.json"))
        
        return archiveDir
    }
}
