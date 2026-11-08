import Foundation
import AppKit
import SwiftData

/// 媒體、相簿與日記多元匯出服務
public final class ExportService {
    public static let shared = ExportService()
    
    private init() {}
    
    // MARK: - 1. 單檔或多選媒體匯出
    public func exportMedia(items: [MediaItem], to destinationFolder: URL) throws -> Int {
        let fileManager = FileManager.default
        var exportedCount = 0
        
        for item in items {
            guard item.fileExistsOnDisk else { continue }
            let sourceURL = item.fileURL
            var targetURL = destinationFolder.appendingPathComponent(item.originalFileName)
            
            // 檔名衝突處理
            if fileManager.fileExists(atPath: targetURL.path) {
                let nameWithoutExt = (item.originalFileName as NSString).deletingPathExtension
                let ext = (item.originalFileName as NSString).pathExtension
                let timestamp = Int(Date().timeIntervalSince1970)
                let newName = ext.isEmpty ? "\(nameWithoutExt)_\(timestamp)" : "\(nameWithoutExt)_\(timestamp).\(ext)"
                targetURL = destinationFolder.appendingPathComponent(newName)
            }
            
            try fileManager.copyItem(at: sourceURL, to: targetURL)
            exportedCount += 1
        }
        
        return exportedCount
    }
    
    // MARK: - 2. 整個自訂相簿匯出
    public func exportAlbum(album: Album, allItems: [MediaItem], to destinationFolder: URL) throws -> (folderURL: URL, exportedCount: Int) {
        let fileManager = FileManager.default
        // 建立相簿命名的子資料夾
        let safeAlbumName = album.name.replacingOccurrences(of: "/", with: "-")
        let albumFolderURL = destinationFolder.appendingPathComponent(safeAlbumName, isDirectory: true)
        
        if !fileManager.fileExists(atPath: albumFolderURL.path) {
            try fileManager.createDirectory(at: albumFolderURL, withIntermediateDirectories: true)
        }
        
        let albumItems = allItems.filter { album.mediaItemIDs.contains($0.id) && !$0.isDeleted }
        let count = try exportMedia(items: albumItems, to: albumFolderURL)
        return (albumFolderURL, count)
    }
    
    // MARK: - 3. 日記匯出為 Markdown (含 YAML Frontmatter)
    public func exportDiaryToMarkdown(entry: DiaryEntry, mediaItems: [MediaItem], to destinationFolder: URL) throws -> URL {
        let fileManager = FileManager.default
        let safeTitle = entry.title.isEmpty ? "Diary_\(entry.id.uuidString.prefix(8))" : entry.title.replacingOccurrences(of: "/", with: "-")
        let fileURL = destinationFolder.appendingPathComponent("\(safeTitle).md")
        
        let isoFormatter = ISO8601DateFormatter()
        let createdStr = isoFormatter.string(from: entry.createdAt)
        let entryDateStr = isoFormatter.string(from: entry.entryDate)
        let tagsYaml = entry.tags.map { "  - \"\($0)\"" }.joined(separator: "\n")
        
        var md = """
        ---
        id: "\(entry.id.uuidString)"
        title: "\(entry.title.replacingOccurrences(of: "\"", with: "\\\""))"
        mood: "\(entry.mood)"
        created_at: "\(createdStr)"
        entry_date: "\(entryDateStr)"
        is_favorite: \(entry.isFavorite)
        tags:
        \(tagsYaml)
        attached_media_count: \(entry.attachedMediaIDs.count)
        ---

        # \(entry.title.isEmpty ? "Untitled Diary" : entry.title)

        \(entry.content)

        """
        
        // 若有附加媒體，列出媒體資訊清單
        let attached = mediaItems.filter { entry.attachedMediaIDs.contains($0.id) }
        if !attached.isEmpty {
            md += "\n## Attached Memories\n"
            for item in attached {
                md += "- **\(item.originalFileName)** (\(item.formattedFileSize))\n"
            }
        }
        
        try md.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    // MARK: - 4. 日記匯出為 JSON
    public func exportDiaryToJSON(entries: [DiaryEntry], to fileURL: URL) throws {
        struct DiaryJSONExport: Codable {
            let id: UUID
            let title: String
            let content: String
            let mood: String
            let createdAt: Date
            let updatedAt: Date
            let entryDate: Date
            let tags: [String]
            let isFavorite: Bool
            let attachedMediaIDs: [UUID]
        }
        
        let exportData = entries.map {
            DiaryJSONExport(
                id: $0.id,
                title: $0.title,
                content: $0.content,
                mood: $0.mood,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt,
                entryDate: $0.entryDate,
                tags: $0.tags,
                isFavorite: $0.isFavorite,
                attachedMediaIDs: $0.attachedMediaIDs
            )
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(exportData)
        try jsonData.write(to: fileURL, options: .atomic)
    }
}
