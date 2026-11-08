import SwiftUI
import SwiftData

/// 全域多維度進階搜尋視圖
public struct AdvancedSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }, sort: \MediaItem.capturedAt, order: .reverse)
    private var allMedia: [MediaItem]
    
    @Query(filter: #Predicate<DiaryEntry> { !$0.isDeleted }, sort: \DiaryEntry.entryDate, order: .reverse)
    private var allDiaries: [DiaryEntry]
    
    @Query private var allAlbums: [Album]
    
    @State private var queryText: String = ""
    @State private var selectedScope: SearchScope = .all
    @State private var isFavoritesOnly: Bool = false
    @State private var enableDateRange: Bool = false
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var selectedTag: String? = nil
    @State private var selectedViewerID: UUID? = nil
    
    @State private var recentSearches: [String] = SearchHistoryService.shared.getRecentSearches()
    
    enum SearchScope: String, CaseIterable, Identifiable {
        case all = "All"
        case photos = "Photos"
        case videos = "Videos"
        case diaries = "Diaries"
        var id: String { rawValue }
    }
    
    public init() {}
    
    // 收集所有標籤
    private var allTags: [String] {
        var tags = Set<String>()
        for m in allMedia { tags.formUnion(m.tags) }
        for d in allDiaries { tags.formUnion(d.tags) }
        return Array(tags).sorted()
    }
    
    // 篩選後之媒體
    private var filteredMedia: [MediaItem] {
        guard selectedScope != .diaries else { return [] }
        return allMedia.filter { item in
            if selectedScope == .photos && item.mediaType != .image { return false }
            if selectedScope == .videos && item.mediaType != .video { return false }
            if isFavoritesOnly && !item.isFavorite { return false }
            if let tag = selectedTag, !item.tags.contains(tag) { return false }
            if enableDateRange && (item.capturedAt < startDate || item.capturedAt > endDate) { return false }
            
            if !queryText.isEmpty {
                let q = queryText.lowercased()
                let matchName = item.originalFileName.lowercased().contains(q)
                let matchCaption = item.caption.lowercased().contains(q)
                let matchTags = item.tags.contains { $0.lowercased().contains(q) }
                let matchMake = item.cameraMake?.lowercased().contains(q) ?? false
                let matchModel = item.cameraModel?.lowercased().contains(q) ?? false
                return matchName || matchCaption || matchTags || matchMake || matchModel
            }
            return true
        }
    }
    
    // 篩選後之日記
    private var filteredDiaries: [DiaryEntry] {
        guard selectedScope == .all || selectedScope == .diaries else { return [] }
        return allDiaries.filter { entry in
            if isFavoritesOnly && !entry.isFavorite { return false }
            if let tag = selectedTag, !entry.tags.contains(tag) { return false }
            if enableDateRange && (entry.entryDate < startDate || entry.entryDate > endDate) { return false }
            
            if !queryText.isEmpty {
                let q = queryText.lowercased()
                let matchTitle = entry.title.lowercased().contains(q)
                let matchContent = entry.content.lowercased().contains(q)
                let matchTags = entry.tags.contains { $0.lowercased().contains(q) }
                return matchTitle || matchContent || matchTags
            }
            return true
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 搜尋輸入框與範圍選單
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    TextField("Search filenames, captions, diary texts, tags, camera models...", text: $queryText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .onSubmit {
                            saveSearchQuery()
                        }
                    
                    if !queryText.isEmpty {
                        Button(action: { queryText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)
                
                // 範圍與篩選標籤
                HStack(spacing: 14) {
                    Picker("Scope", selection: $selectedScope) {
                        ForEach(SearchScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                    
                    Toggle("Favorites Only", isOn: $isFavoritesOnly)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    
                    Toggle("Date Range", isOn: $enableDateRange)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    
                    if enableDateRange {
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .labelsHidden()
                        Text("to")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    
                    Spacer()
                }
                
                // 最近搜尋歷史紀錄
                if !recentSearches.isEmpty && queryText.isEmpty {
                    HStack(spacing: 8) {
                        Text("Recent:")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                        
                        ForEach(recentSearches.prefix(5), id: \.self) { search in
                            Button(search) {
                                queryText = search
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                        
                        Spacer()
                        
                        Button("Clear") {
                            SearchHistoryService.shared.clearAllSearches()
                            recentSearches = []
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding(18)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // MARK: - 搜尋結果區
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 摘要標籤
                    HStack {
                        Text("Found \(filteredMedia.count) media, \(filteredDiaries.count) diaries")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    // 日記結果
                    if !filteredDiaries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Diaries (\(filteredDiaries.count))")
                                .font(.headline)
                            
                            ForEach(filteredDiaries) { entry in
                                Button(action: {
                                    dismiss()
                                    appState.openDiaryComposer(entry: entry)
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(entry.mood)
                                            Text(entry.title.isEmpty ? "Untitled Diary" : entry.title)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Text(entry.entryDate.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Text(entry.content)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    .padding(12)
                                    .background(Color.secondary.opacity(0.05))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // 媒體結果
                    if !filteredMedia.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Media (\(filteredMedia.count))")
                                .font(.headline)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 12)], spacing: 12) {
                                ForEach(filteredMedia) { item in
                                    Button(action: { selectedViewerID = item.id }) {
                                        MediaGridCard(item: item, isSelected: false)
                                            .frame(height: 110)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    if filteredMedia.isEmpty && filteredDiaries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("No memories matched your query.")
                                .font(.headline)
                            Text("Try adjusting your filters or search terms.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 780, height: 560)
        .sheet(isPresented: Binding(
            get: { selectedViewerID != nil },
            set: { if !$0 { selectedViewerID = nil } }
        )) {
            MediaViewerModal(items: filteredMedia, currentItemID: $selectedViewerID)
        }
    }
    
    private func saveSearchQuery() {
        SearchHistoryService.shared.addSearchQuery(queryText)
        recentSearches = SearchHistoryService.shared.getRecentSearches()
    }
}
