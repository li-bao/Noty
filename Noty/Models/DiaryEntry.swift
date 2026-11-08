import Foundation
import SwiftData

/// 私人日記實體（DiaryEntry）
@Model
public final class DiaryEntry {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var content: String
    public var createdAt: Date
    public var updatedAt: Date
    public var entryDate: Date
    public var attachedMediaIDs: [UUID]
    public var tags: [String]
    public var isFavorite: Bool
    public var isDeleted: Bool
    public var deletedAt: Date?
    public var mood: String
    
    // MARK: - Phase 9.875 重要回憶與防誤刪保護
    public var isImportant: Bool = false
    public var isProtected: Bool = false
    
    public init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        entryDate: Date = Date(),
        attachedMediaIDs: [UUID] = [],
        tags: [String] = [],
        isFavorite: Bool = false,
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        mood: String = "😊",
        isImportant: Bool = false,
        isProtected: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.entryDate = entryDate
        self.attachedMediaIDs = attachedMediaIDs
        self.tags = tags
        self.isFavorite = isFavorite
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.mood = mood
        self.isImportant = isImportant
        self.isProtected = isProtected
    }
}

/// 兼容性別名（供舊代碼無縫過渡）
public typealias DiaryPost = DiaryEntry
