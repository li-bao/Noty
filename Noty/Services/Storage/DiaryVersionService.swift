import Foundation
import SwiftData

/// 日記歷史版本資料模型
public struct DiaryVersion: Codable, Identifiable, Sendable {
    public let id: UUID
    public let diaryID: UUID
    public let versionNumber: Int
    public let savedAt: Date
    public let title: String
    public let content: String
    public let mood: String
    public let tags: [String]
    
    public init(
        id: UUID = UUID(),
        diaryID: UUID,
        versionNumber: Int,
        savedAt: Date = Date(),
        title: String,
        content: String,
        mood: String,
        tags: [String] = []
    ) {
        self.id = id
        self.diaryID = diaryID
        self.versionNumber = versionNumber
        self.savedAt = savedAt
        self.title = title
        self.content = content
        self.mood = mood
        self.tags = tags
    }
}

/// 日記版本歷史管理服務（DiaryVersionService）
/// 負責保存每次重大儲存的歷史快照，支援歷史版本比對、還原舊版與另存副本
public final class DiaryVersionService: @unchecked Sendable {
    public static let shared = DiaryVersionService()
    
    private let fileManager = FileManager.default
    private let versionsDirectory: URL
    private let lock = NSLock()
    
    private init() {
        let storage = StorageService.shared
        self.versionsDirectory = storage.databaseDirectory.appendingPathComponent("Versions", isDirectory: true)
        try? fileManager.createDirectory(at: versionsDirectory, withIntermediateDirectories: true)
    }
    
    private func versionsFileURL(for diaryID: UUID) -> URL {
        versionsDirectory.appendingPathComponent("\(diaryID.uuidString).json")
    }
    
    /// 載入特定日記的所有歷史版本（由新至舊）
    public func getVersions(for diaryID: UUID) -> [DiaryVersion] {
        lock.lock()
        defer { lock.unlock() }
        
        let file = versionsFileURL(for: diaryID)
        guard fileManager.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file) else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let list = (try? decoder.decode([DiaryVersion].self, from: data)) ?? []
        return list.sorted { $0.versionNumber > $1.versionNumber }
    }
    
    /// 保存歷史快照（自動去重：若內容無實質變更則不重複保存）
    public func saveSnapshot(for diary: DiaryEntry) {
        lock.lock()
        defer { lock.unlock() }
        
        var versions = getVersionsInternal(for: diary.id)
        if let latest = versions.first {
            if latest.title == diary.title && latest.content == diary.content && latest.mood == diary.mood {
                // 內容完全相同，無需產生冗餘版本
                return
            }
        }
        
        let nextVer = (versions.first?.versionNumber ?? 0) + 1
        let newVersion = DiaryVersion(
            diaryID: diary.id,
            versionNumber: nextVer,
            savedAt: Date(),
            title: diary.title,
            content: diary.content,
            mood: diary.mood,
            tags: diary.tags
        )
        
        versions.insert(newVersion, at: 0)
        
        // 限制最多保存最近 20 個版本
        let trimmed = Array(versions.prefix(20))
        saveVersionsInternal(trimmed, for: diary.id)
    }
    
    private func getVersionsInternal(for diaryID: UUID) -> [DiaryVersion] {
        let file = versionsFileURL(for: diaryID)
        guard fileManager.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([DiaryVersion].self, from: data)) ?? []
    }
    
    private func saveVersionsInternal(_ versions: [DiaryVersion], for diaryID: UUID) {
        let file = versionsFileURL(for: diaryID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(versions) {
            try? data.write(to: file)
        }
    }
}
