import SwiftUI
import SwiftData

/// 原生 macOS 風格回憶日曆視圖（Calendar View）
public struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }, sort: \MediaItem.capturedAt, order: .reverse)
    private var allMedia: [MediaItem]
    
    @Query(filter: #Predicate<DiaryEntry> { !$0.isDeleted }, sort: \DiaryEntry.entryDate, order: .reverse)
    private var allDiaries: [DiaryEntry]
    
    @State private var currentMonthDate: Date = Date()
    @State private var selectedDayDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedViewerID: UUID? = nil
    
    private let calendar = Calendar.current
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 0) {
            // MARK: - 左側日曆主網格
            VStack(spacing: 0) {
                calendarHeaderSection
                
                Divider()
                    .padding(.horizontal, 24)
                
                weekdayHeaderRow
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                
                daysGrid
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // MARK: - 右側當日回憶面板 (Selected Day Inspector)
            selectedDayPanel
                .frame(minWidth: 260, idealWidth: 310, maxWidth: 350)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        }
        .sheet(isPresented: Binding(
            get: { selectedViewerID != nil },
            set: { if !$0 { selectedViewerID = nil } }
        )) {
            MediaViewerModal(items: dayMediaItems, currentItemID: $selectedViewerID)
        }
    }
    
    // MARK: - 日曆月度導航標題
    private var calendarHeaderSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Memory Calendar")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                Text(monthYearTitle(currentMonthDate))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("Today") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        currentMonthDate = Date()
                        selectedDayDate = calendar.startOfDay(for: Date())
                    }
                }
                .buttonStyle(.notySecondary(height: 28))
                
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.notyIcon(size: 28))
                .help("Previous Month")
                
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.notyIcon(size: 28))
                .help("Next Month")
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }
    
    // 星期列
    private var weekdayHeaderRow: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // 日曆格子
    private var daysGrid: some View {
        let days = generateDaysInMonth(for: currentMonthDate)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days, id: \.self) { date in
                if let date = date {
                    dayCell(for: date)
                } else {
                    Color.clear
                        .aspectRatio(1.0, contentMode: .fill)
                }
            }
        }
    }
    
    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDayDate)
        let isToday = calendar.isDateInToday(date)
        let mediaCount = mediaCountForDay(date)
        let diaryCount = diaryCountForDay(date)
        let hasMemory = (mediaCount + diaryCount) > 0
        let dayNumber = calendar.component(.day, from: date)
        
        Button(action: {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedDayDate = date
            }
        }) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Text("\(dayNumber)")
                        .font(.system(size: 13, weight: isSelected ? .bold : (isToday ? .bold : .medium)))
                        .foregroundColor(isSelected ? .white : (isToday ? .accentColor : .primary))
                    
                    if hasMemory {
                        HStack(spacing: 3) {
                            if mediaCount > 0 {
                                Circle()
                                    .fill(isSelected ? .white : Color.blue)
                                    .frame(width: 5, height: 5)
                            }
                            if diaryCount > 0 {
                                Circle()
                                    .fill(isSelected ? .white : Color.orange)
                                    .frame(width: 5, height: 5)
                            }
                        }
                    } else {
                        Spacer().frame(height: 5)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1.1, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.accentColor : (isToday ? Color.accentColor.opacity(0.12) : (hasMemory ? Color.secondary.opacity(0.06) : Color.clear)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isToday && !isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                )
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 當日回憶抽屜面板
    private var dayMediaItems: [MediaItem] {
        allMedia.filter { calendar.isDate($0.capturedAt, inSameDayAs: selectedDayDate) }
    }
    
    private var dayDiaries: [DiaryEntry] {
        allDiaries.filter { calendar.isDate($0.entryDate, inSameDayAs: selectedDayDate) }
    }
    
    private var selectedDayPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 日期標題
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate(selectedDayDate))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                
                Text("\(dayMediaItems.count) media • \(dayDiaries.count) diaries")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 日記區
                    if !dayDiaries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Diaries")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            ForEach(dayDiaries) { diary in
                                Button(action: { appState.openDiaryComposer(entry: diary) }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(diary.mood)
                                                .fixedSize()
                                            Text(diary.title.isEmpty ? "Diary Entry" : diary.title)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        if !diary.content.isEmpty {
                                            Text(diary.content)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.secondary.opacity(0.06))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // 媒體相簿區
                    if !dayMediaItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Photos & Videos")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 8)], spacing: 8) {
                                ForEach(dayMediaItems) { item in
                                    Button(action: { selectedViewerID = item.id }) {
                                        MediaGridCard(item: item, isSelected: false)
                                            .frame(height: 80)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    if dayDiaries.isEmpty && dayMediaItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("No memories recorded on this day.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                appState.openDiaryComposer()
                            }) {
                                Label("Write Diary", systemImage: "pencil")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }
    
    // MARK: - 輔助演算法
    private func changeMonth(by amount: Int) {
        if let newDate = calendar.date(byAdding: .month, value: amount, to: currentMonthDate) {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentMonthDate = newDate
            }
        }
    }
    
    private func monthYearTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    private func mediaCountForDay(_ date: Date) -> Int {
        allMedia.filter { calendar.isDate($0.capturedAt, inSameDayAs: date) }.count
    }
    
    private func diaryCountForDay(_ date: Date) -> Int {
        allDiaries.filter { calendar.isDate($0.entryDate, inSameDayAs: date) }.count
    }
    
    private func generateDaysInMonth(for date: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let firstDayOfMonth = monthInterval.start
        let weekdayOfFirstDay = calendar.component(.weekday, from: firstDayOfMonth) - 1
        let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        
        var days: [Date?] = Array(repeating: nil, count: weekdayOfFirstDay)
        for day in 1...numberOfDaysInMonth {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(d)
            }
        }
        return days
    }
}
