import Foundation

/// 本機搜尋歷史管理服務（100% 本地儲存、可隨時清除）
public final class SearchHistoryService {
    public static let shared = SearchHistoryService()
    
    private let userDefaultsKey = "noty_recent_searches"
    private let maxHistoryCount = 10
    
    private init() {}
    
    public func getRecentSearches() -> [String] {
        return UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
    }
    
    public func addSearchQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var searches = getRecentSearches()
        searches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        searches.insert(trimmed, at: 0)
        
        if searches.count > maxHistoryCount {
            searches = Array(searches.prefix(maxHistoryCount))
        }
        
        UserDefaults.standard.set(searches, forKey: userDefaultsKey)
    }
    
    public func removeSearchQuery(_ query: String) {
        var searches = getRecentSearches()
        searches.removeAll { $0 == query }
        UserDefaults.standard.set(searches, forKey: userDefaultsKey)
    }
    
    public func clearAllSearches() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
