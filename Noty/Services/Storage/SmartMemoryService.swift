import Foundation
import SwiftData

/// 智慧相簿類型枚舉
public enum SmartAlbumCategory: String, CaseIterable, Identifiable, Sendable {
    case recentlyViewed = "Recently Viewed"
    case notYetOrganized = "Not Yet Organized"
    case largeVideos = "Large Videos (>100MB)"
    case memoriesWithoutDiary = "Memories Without Diary"
    case unusedFavorites = "Unused Favorites"
    case important = "Important Memories"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .recentlyViewed: return "eye.fill"
        case .notYetOrganized: return "tray.fill"
        case .largeVideos: return "film.stack.fill"
        case .memoriesWithoutDiary: return "book.closed.fill"
        case .unusedFavorites: return "heart.slash.fill"
        case .important: return "star.fill"
        }
    }
}

/// 智慧相簿與關聯回憶推薦服務（SmartMemoryService）
/// 純動態查詢，絕不冗餘複製原始檔案
public final class SmartMemoryService: @unchecked Sendable {
    public static let shared = SmartMemoryService()
    
    private init() {}
    
    /// 依據智慧分類動態過濾媒體
    public func filterMedia(
        by category: SmartAlbumCategory,
        in allItems: [MediaItem],
        allDiaries: [DiaryEntry]
    ) -> [MediaItem] {
        let activeItems = allItems.filter { !$0.isDeleted }
        
        switch category {
        case .recentlyViewed:
            return activeItems
                .filter { $0.lastViewedAt != nil }
                .sorted { ($0.lastViewedAt ?? Date.distantPast) > ($1.lastViewedAt ?? Date.distantPast) }
            
        case .notYetOrganized:
            return activeItems.filter { $0.albumIDs.isEmpty }
            
        case .largeVideos:
            // 大於 100 MB 的影片
            return activeItems.filter {
                $0.mediaType == .video && $0.fileSizeBytes > (100 * 1024 * 1024)
            }
            
        case .memoriesWithoutDiary:
            let attachedIDs = Set(allDiaries.filter { !$0.isDeleted }.flatMap { $0.attachedMediaIDs })
            return activeItems.filter { !attachedIDs.contains($0.id) }
            
        case .unusedFavorites:
            return activeItems.filter { $0.isFavorite && $0.albumIDs.isEmpty }
            
        case .important:
            return activeItems.filter { $0.isImportant }
        }
    }
    
    /// 本機關聯回憶推薦引擎
    /// 依據拍攝日期鄰近度（±3 天）、標籤共同度或相同相簿進行關聯打分
    public func findRelatedMemories(
        for targetItem: MediaItem,
        in allItems: [MediaItem],
        limit: Int = 6
    ) -> [MediaItem] {
        let candidates = allItems.filter { !$0.isDeleted && $0.id != targetItem.id }
        let calendar = Calendar.current
        let targetTags = Set(targetItem.tags)
        let targetAlbums = Set(targetItem.albumIDs)
        
        var scored: [(item: MediaItem, score: Int)] = []
        
        for candidate in candidates {
            var score = 0
            
            // 1. 日期接近度（3 天內 +3 分，7 天內 +1 分）
            let dayDiff = abs(calendar.dateComponents([.day], from: targetItem.capturedAt, to: candidate.capturedAt).day ?? 999)
            if dayDiff <= 3 {
                score += 3
            } else if dayDiff <= 7 {
                score += 1
            }
            
            // 2. 標籤相符（每個相同標籤 +2 分）
            let commonTags = targetTags.intersection(Set(candidate.tags))
            score += commonTags.count * 2
            
            // 3. 同相簿相符（每個共同相簿 +3 分）
            let commonAlbums = targetAlbums.intersection(Set(candidate.albumIDs))
            score += commonAlbums.count * 3
            
            if score > 0 {
                scored.append((candidate, score))
            }
        }
        
        scored.sort { $0.score > $1.score }
        return Array(scored.prefix(limit).map { $0.item })
    }
}
