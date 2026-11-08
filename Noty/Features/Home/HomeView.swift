import SwiftUI
import SwiftData

/// 首頁概覽視圖（Home View）
public struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }) private var mediaItems: [MediaItem]
    @Query(filter: #Predicate<DiaryEntry> { !$0.isDeleted }) private var diaryEntries: [DiaryEntry]
    
    private var onThisDayMemories: [OnThisDayMemory] {
        OnThisDayService.shared.fetchMemoriesOnThisDay(mediaItems: mediaItems, diaries: diaryEntries)
    }
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // 頂部歡迎卡片
                VStack(alignment: .leading, spacing: 8) {
                    Text(greetingText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    
                    Text("Here is your private corner of memories, safe and sound on your Mac.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 10)
                
                // 統計數據指標卡片
                HStack(spacing: 16) {
                    statCard(title: "Photos", count: mediaItems.filter { $0.mediaType == .image }.count, icon: "photo.stack", color: .blue)
                    statCard(title: "Videos", count: mediaItems.filter { $0.mediaType == .video }.count, icon: "film.stack", color: .purple)
                    statCard(title: "Diaries", count: diaryEntries.count, icon: "book.pages", color: .orange)
                    statCard(title: "Favorites", count: mediaItems.filter { $0.isFavorite }.count, icon: "heart.fill", color: .red)
                }
                
                // MARK: - 今日回憶時光機 (On This Day Time Machine)
                if let featured = onThisDayMemories.first {
                    OnThisDayCardView(
                        memory: featured,
                        onSelectMedia: { _ in
                            appState.selectedTab = .gallery
                        },
                        onSelectDiary: { diary in
                            appState.openDiaryComposer(entry: diary)
                        }
                    )
                }
                
                // 快速操作區域
                HStack(spacing: 16) {
                    quickActionCard(
                        title: "Create Memory",
                        subtitle: "Record a new diary or upload media",
                        icon: "square.and.pencil",
                        action: { appState.openDiaryComposer() }
                    )
                    
                    quickActionCard(
                        title: "Browse Gallery",
                        subtitle: "View your media memories timeline",
                        icon: "photo.on.rectangle.angled",
                        action: { appState.selectedTab = .gallery }
                    )
                }
                
                // 最近發布之日記
                if !diaryEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Recent Thoughts")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Spacer()
                            Button("View All") {
                                appState.selectedTab = .diary
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                            .font(.system(size: 13, weight: .medium))
                        }
                        
                        ForEach(diaryEntries.prefix(3)) { post in
                            Button(action: {
                                appState.openDiaryComposer(entry: post)
                            }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(post.mood)
                                            .font(.title3)
                                            .fixedSize()
                                        Text(post.title.isEmpty ? "Diary Entry" : post.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(post.entryDate.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if !post.content.isEmpty {
                                        Text(post.content)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                .padding(14)
                                .background(Color.secondary.opacity(0.06))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(28)
        }
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning ☀️" }
        if hour < 18 { return "Good afternoon ☕️" }
        return "Good evening 🌙"
    }
    
    private func statCard(title: String, count: Int, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(14)
    }
    
    private func quickActionCard(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}
