import SwiftUI
import SwiftData

/// 日期篩選區間枚舉
public enum TimelineDateFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case custom = "Custom Date"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .all: return "All"
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .custom: return "Custom Date"
        }
    }
}

/// 時間軸檢視模式
public enum TimelineContentMode: String, CaseIterable, Identifiable {
    case composite = "Memories"
    case diariesOnly = "Diaries"
    case mediaOnly = "Photos & Videos"
    
    public var id: String { rawValue }
}

/// 私人日記與 Instagram 風格圖文時間軸（Diary / Timeline View）
public struct DiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    
    @Query(filter: #Predicate<DiaryEntry> { !$0.isDeleted }, sort: \DiaryEntry.entryDate, order: .reverse)
    private var allDiaries: [DiaryEntry]
    
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }, sort: \MediaItem.capturedAt, order: .reverse)
    private var allMediaItems: [MediaItem]
    
    @State private var searchKeyword: String = ""
    @State private var dateFilter: TimelineDateFilter = .all
    @State private var contentMode: TimelineContentMode = .composite
    @State private var selectedMoodFilter: String = "All"
    @State private var isAscending: Bool = false
    
    // 自訂日期選擇
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var showCustomDatePicker: Bool = false
    
    // 編輯與新增視窗
    @State private var editingEntry: DiaryEntry? = nil
    @State private var isComposerPresented: Bool = false
    
    private let availableMoods = ["All", "😊", "☕️", "🌟", "🏖️", "💻", "🌧️", "🌿", "🎉", "❤️"]
    
    public init() {}
    
    // MARK: - 日期分組資料模型
    private struct DayGroup: Identifiable {
        let date: Date
        let diaries: [DiaryEntry]
        let mediaItems: [MediaItem]
        var id: Date { date }
    }
    
    private var filteredDayGroups: [DayGroup] {
        let calendar = Calendar.current
        let kw = searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // 1. 篩選日記
        var filteredDiaries = allDiaries.filter { entry in
            // 關鍵字
            let matchesKeyword = kw.isEmpty ||
                entry.title.localizedCaseInsensitiveContains(kw) ||
                entry.content.localizedCaseInsensitiveContains(kw) ||
                entry.tags.contains { $0.localizedCaseInsensitiveContains(kw) } ||
                entry.mood.contains(kw)
            
            // 心情
            let matchesMood = (selectedMoodFilter == "All") || (entry.mood == selectedMoodFilter)
            
            // 日期區間
            let matchesDate = matchesDateFilter(date: entry.entryDate, calendar: calendar)
            
            return matchesKeyword && matchesMood && matchesDate
        }
        
        // 2. 篩選媒體
        var filteredMedia = allMediaItems.filter { media in
            let matchesKeyword = kw.isEmpty ||
                media.originalFileName.localizedCaseInsensitiveContains(kw) ||
                media.caption.localizedCaseInsensitiveContains(kw) ||
                media.tags.contains { $0.localizedCaseInsensitiveContains(kw) }
            
            let matchesDate = matchesDateFilter(date: media.capturedAt, calendar: calendar)
            return matchesKeyword && matchesDate
        }
        
        // 依檢視模式剔除不需顯示的資料
        if contentMode == .diariesOnly {
            filteredMedia.removeAll()
        } else if contentMode == .mediaOnly {
            filteredDiaries.removeAll()
        }
        
        // 3. 依「日」歸納分組
        var dayMap: [Date: ([DiaryEntry], [MediaItem])] = [:]
        
        for diary in filteredDiaries {
            let dayStart = calendar.startOfDay(for: diary.entryDate)
            var current = dayMap[dayStart] ?? ([], [])
            current.0.append(diary)
            dayMap[dayStart] = current
        }
        
        for media in filteredMedia {
            let dayStart = calendar.startOfDay(for: media.capturedAt)
            var current = dayMap[dayStart] ?? ([], [])
            current.1.append(media)
            dayMap[dayStart] = current
        }
        
        var groups = dayMap.map { DayGroup(date: $0.key, diaries: $0.value.0, mediaItems: $0.value.1) }
        
        // 4. 排序
        if isAscending {
            groups.sort { $0.date < $1.date }
        } else {
            groups.sort { $0.date > $1.date }
        }
        
        return groups
    }
    
    private func matchesDateFilter(date: Date, calendar: Calendar) -> Bool {
        let now = Date()
        switch dateFilter {
        case .all:
            return true
        case .today:
            return calendar.isDateInToday(date)
        case .yesterday:
            return calendar.isDateInYesterday(date)
        case .thisWeek:
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return true }
            return date >= calendar.startOfDay(for: weekAgo) && date <= now
        case .thisMonth:
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .custom:
            let start = calendar.startOfDay(for: customStartDate)
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate) ?? customEndDate
            return date >= start && date <= end
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 1. 頂部導航與主要動作列
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("You are now at")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("Timeline & Memories 📖")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.accentColor)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    
                    Text("Personal Timeline")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .layoutPriority(1)
                }
                
                Spacer(minLength: 12)
                
                // 檢視模式選擇（全部回憶 / 純日記 / 純照片影片 — 全面升級為 Apple Liquid Glass 膠囊）
                HStack(spacing: 6) {
                    ForEach(TimelineContentMode.allCases) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                contentMode = mode
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: modeIcon(for: mode))
                                    .font(.system(size: 11, weight: .semibold))
                                Text(mode.rawValue)
                                    .font(.system(size: 12, weight: contentMode == mode ? .bold : .medium, design: .rounded))
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundColor(contentMode == mode ? .accentColor : .secondary)
                            .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .liquidCapsule(isActive: contentMode == mode, isInteractive: true)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
                
                Divider()
                    .frame(height: 18)
                    .opacity(0.4)
                
                // 新增日記按鈕（升級為 Liquid Glass Primary 按鈕，保證獨立間距，絕不遮擋選項）
                Button(action: {
                    editingEntry = nil
                    isComposerPresented = true
                }) {
                    Label("Write Diary", systemImage: "square.and.pencil")
                }
                .buttonStyle(.notyPrimary(height: 32))
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            // MARK: - 2. 日期篩選、心情過濾與搜尋列
            HStack(spacing: 12) {
                // 日期區間膠囊（支援純滑鼠滾輪橫向滑動）
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(TimelineDateFilter.allCases) { filter in
                            Button(action: {
                                dateFilter = filter
                                if filter == .custom {
                                    showCustomDatePicker = true
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text(filter.title)
                                        .font(.system(size: 11, weight: dateFilter == filter ? .bold : .medium))
                                    if filter == .custom && dateFilter == .custom {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 10))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .foregroundColor(dateFilter == filter ? .accentColor : .secondary)
                                .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                            .liquidCapsule(isActive: dateFilter == filter, isInteractive: true)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 2)
                }
                .horizontalWheelScroll()
                
                Spacer(minLength: 8)
                
                // 心情過濾（Liquid Glass 圓潤微泡，字體與高度充足，絕不切掉 Emoji）
                if contentMode != .mediaOnly {
                    HStack(spacing: 5) {
                        Text("Mood:")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        ForEach(availableMoods, id: \.self) { mood in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedMoodFilter = mood
                                }
                            }) {
                                Text(mood)
                                    .font(.system(size: mood == "All" ? 11 : 14, weight: selectedMoodFilter == mood ? .bold : .medium))
                                    .fixedSize()
                                    .frame(minWidth: mood == "All" ? 30 : 26, minHeight: 26)
                                    .padding(.horizontal, mood == "All" ? 6 : 2)
                            }
                            .buttonStyle(.plain)
                            .liquidCapsule(isActive: selectedMoodFilter == mood, isInteractive: true)
                        }
                    }
                }
                
                // 搜尋框
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    TextField("Search memories, tags...", text: $searchKeyword)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .frame(minWidth: 100, maxWidth: 150)
                    
                    if !searchKeyword.isEmpty {
                        Button(action: { searchKeyword = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.08))
                .clipShape(Capsule())
                
                // 升降排序切換（Liquid Glass 圓形圖示按鈕）
                Button(action: {
                    withAnimation { isAscending.toggle() }
                }) {
                    Image(systemName: isAscending ? "arrow.up" : "arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.notyIcon(size: 28))
                .help(isAscending ? "Oldest first" : "Newest first")
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
            
            // 自訂日期指示橫幅
            if dateFilter == .custom {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.accentColor)
                    
                    DatePicker("From", selection: $customStartDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    
                    Text("to")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DatePicker("To", selection: $customEndDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    
                    Spacer()
                    
                    Button("Clear Filter") {
                        dateFilter = .all
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.04))
            }
            
            Divider()
                .padding(.horizontal, 28)
            
            // MARK: - 3. 主內容區（時間軸清單）
            if filteredDayGroups.isEmpty {
                emptyTimelineView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredDayGroups) { dayGroup in
                            TimelineDaySectionView(
                                date: dayGroup.date,
                                diaries: dayGroup.diaries,
                                mediaItems: dayGroup.mediaItems,
                                contentMode: contentMode,
                                onEditDiary: { entry in
                                    editingEntry = entry
                                    isComposerPresented = true
                                },
                                onCreateDiaryWithMedia: { media in
                                    // 攜帶該媒體直接建立新日記
                                    editingEntry = nil
                                    isComposerPresented = true
                                    // 存入草稿以攜帶此媒體
                                    let draft = DiaryDraft(
                                        entryDate: media.capturedAt,
                                        attachedMediaIDs: [media.id],
                                        tags: media.tags
                                    )
                                    DiaryDraftService.shared.saveDraft(draft)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 36)
                    .padding(.top, 24)
                    .frame(maxWidth: 720)
                }
            }
        }
        .sheet(isPresented: $isComposerPresented) {
            DiaryComposerSheet(entry: editingEntry)
        }
    }
    
    // MARK: - 空狀態檢視
    private var emptyTimelineView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "book.pages")
                    .font(.system(size: 38))
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 6) {
                Text(searchKeyword.isEmpty && dateFilter == .all ? "No memories yet" : "No matching memories found")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                
                Text(searchKeyword.isEmpty && dateFilter == .all ? "Write your first daily thoughts, or import photos and videos to organize into your private timeline." : "Try adjusting your search keyword or selected date range.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    editingEntry = nil
                    isComposerPresented = true
                }) {
                    Label("Write First Diary", systemImage: "pencil")
                }
                .buttonStyle(.notyPrimary(height: 32))
                
                Button(action: {
                    appState.isUploadSheetPresented = true
                }) {
                    Label("Upload Media", systemImage: "photo.badge.plus")
                }
                .buttonStyle(.notySecondary(height: 32))
            }
            .padding(.top, 6)
            
            Spacer()
        }
    }
    
    private func modeIcon(for mode: TimelineContentMode) -> String {
        switch mode {
        case .composite: return "sparkles.rectangle.stack"
        case .diariesOnly: return "book.closed.fill"
        case .mediaOnly: return "photo.on.rectangle.angled"
        }
    }
}
