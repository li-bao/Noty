import Foundation
import SwiftData

/// 自訂相簿模型（Album）
/// 支援同一媒體歸屬於多個自訂相簿，刪除相簿絕不連帶刪除原始媒體實體
@Model
public final class Album {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var coverMediaID: UUID?
    public var mediaItemIDs: [UUID]
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        coverMediaID: UUID? = nil,
        mediaItemIDs: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.coverMediaID = coverMediaID
        self.mediaItemIDs = mediaItemIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
