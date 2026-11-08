import Foundation
import SwiftData

/// 今日回憶項目結構
public struct OnThisDayMemory: Identifiable, Sendable {
    public let id = UUID()
    public let yearsAgo: Int
    public let year: Int
    public let date: Date
    public let mediaItems: [MediaItem]
    public let diaries: [DiaryEntry]
    
    public var totalCount: Int {
        mediaItems.count + diaries.count
    }
}

/// 今日回憶時間時光機服務（OnThisDayService）
/// 純本機演算法，依據使用者本機時區與拍攝/日記日期，檢索 1/2/3/5+ 年前的今日回憶
public final class OnThisDayService: @unchecked Sendable {
    public static let shared = OnThisDayService()
    
    private init() {}
    
    /// 檢索指定參考日期（預設為今天）的多年歷史回憶
    public func fetchMemoriesOnThisDay(
        mediaItems: [MediaItem],
        diaries: [DiaryEntry],
        referenceDate: Date = Date()
    ) -> [OnThisDayMemory] {
        let calendar = Calendar.current
        let targetMonth = calendar.component(.month, from: referenceDate)
        let targetDay = calendar.component(.day, from: referenceDate)
        let targetYear = calendar.component(.year, from: referenceDate)
        
        // 篩選未刪除之媒體
        let validMedia = mediaItems.filter { item in
            guard !item.isDeleted else { return false }
            let m = calendar.component(.month, from: item.capturedAt)
            let d = calendar.component(.day, from: item.capturedAt)
            let y = calendar.component(.year, from: item.capturedAt)
            return m == targetMonth && d == targetDay && y < targetYear
        }
        
        // 篩選未刪除之日記
        let validDiaries = diaries.filter { diary in
            guard !diary.isDeleted else { return false }
            let m = calendar.component(.month, from: diary.entryDate)
            let d = calendar.component(.day, from: diary.entryDate)
            let y = calendar.component(.year, from: diary.entryDate)
            return m == targetMonth && d == targetDay && y < targetYear
        }
        
        // 取得所有涵蓋之歷史年份
        var mediaByYear: [Int: [MediaItem]] = [:]
        for item in validMedia {
            let y = calendar.component(.year, from: item.capturedAt)
            mediaByYear[y, default: []].append(item)
        }
        
        var diariesByYear: [Int: [DiaryEntry]] = [:]
        for diary in validDiaries {
            let y = calendar.component(.year, from: diary.entryDate)
            diariesByYear[y, default: []].append(diary)
        }
        
        let allYears = Set(mediaByYear.keys).union(Set(diariesByYear.keys)).sorted(by: >)
        
        var result: [OnThisDayMemory] = []
        for year in allYears {
            let yearsAgo = targetYear - year
            guard yearsAgo > 0 else { continue }
            
            var components = DateComponents()
            components.year = year
            components.month = targetMonth
            components.day = targetDay
            let memoryDate = calendar.date(from: components) ?? referenceDate
            
            let mList = mediaByYear[year] ?? []
            let dList = diariesByYear[year] ?? []
            
            result.append(OnThisDayMemory(
                yearsAgo: yearsAgo,
                year: year,
                date: memoryDate,
                mediaItems: mList,
                diaries: dList
            ))
        }
        
        return result
    }
}
