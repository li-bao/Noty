import SwiftUI
import SwiftData
import AVKit

/// Instagram 風格之私人圖文日記動態卡片（DiaryPostCardView）
public struct DiaryPostCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }) private var allMedia: [MediaItem]
    
    @Bindable var entry: DiaryEntry
    var onEdit: () -> Void
    
    @State private var currentMediaIndex: Int = 0
    @State private var selectedMediaIDForViewer: UUID? = nil
    @State private var isViewerPresented: Bool = false
    
    public init(entry: DiaryEntry, onEdit: @escaping () -> Void) {
        self.entry = entry
        self.onEdit = onEdit
    }
    
    private var attachedItems: [MediaItem] {
        let mediaMap = Dictionary(uniqueKeysWithValues: allMedia.map { ($0.id, $0) })
        return entry.attachedMediaIDs.compactMap { mediaMap[$0] }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - 1. 卡片頂部（作者/心情報告、標題、時間與操作）
            HStack(alignment: .center, spacing: 12) {
                // 心情頭像徽章（Apple Liquid Glass 微氣泡造型，字體飽滿，絕不切掉 Emoji）
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: Color.accentColor.opacity(0.12), radius: 6, x: 0, y: 2)
                    
                    Text(entry.mood)
                        .font(.system(size: 24))
                        .fixedSize()
                }
                .frame(width: 46, height: 46)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title.isEmpty ? "Personal Memory" : entry.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Text(entry.entryDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        if !entry.tags.isEmpty {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(entry.tags.map { "#\($0)" }.joined(separator: " "))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.accentColor)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                // 喜愛收藏按鈕
                Button(action: {
                    entry.isFavorite.toggle()
                    try? modelContext.save()
                }) {
                    Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundColor(entry.isFavorite ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .help(entry.isFavorite ? "Unlike" : "Like memory")
                
                // 操作選單
                Menu {
                    Button(action: onEdit) {
                        Label("Edit Diary", systemImage: "pencil")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: {
                        entry.isDeleted = true
                        entry.deletedAt = Date()
                        try? modelContext.save()
                    }) {
                        Label("Move to Trash", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            
            // MARK: - 2. 媒體輪播與呈現區塊（Instagram 風格多圖/影片）
            if !attachedItems.isEmpty {
                mediaCarouselSection
            }
            
            // MARK: - 3. 日記正文
            if !entry.content.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.content)
                        .font(.system(size: 14))
                        .lineSpacing(5)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            
            // MARK: - 4. 底部標籤與狀態
            if !entry.tags.isEmpty || attachedItems.count > 1 {
                HStack {
                    if !entry.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(entry.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 11, weight: .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if !attachedItems.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 10))
                            Text("\(attachedItems.count) media")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        .sheet(isPresented: Binding(
            get: { selectedMediaIDForViewer != nil },
            set: { if !$0 { selectedMediaIDForViewer = nil } }
        )) {
            MediaViewerModal(
                items: attachedItems,
                currentItemID: $selectedMediaIDForViewer
            )
        }
    }
    
    // MARK: - 媒體輪播區
    private var mediaCarouselSection: some View {
        ZStack(alignment: .bottom) {
            let activeIndex = min(max(currentMediaIndex, 0), max(attachedItems.count - 1, 0))
            let currentItem = attachedItems[activeIndex]
            
            ZStack {
                if let nsImage = ThumbnailService.shared.loadCachedThumbnail(for: currentItem.storedFileName) ?? (currentItem.mediaType == .image ? NSImage(contentsOf: currentItem.fileURL) : nil) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 380)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 380)
                        .overlay(
                            Image(systemName: currentItem.mediaType == .video ? "film" : "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                        )
                }
                
                // 影片播放指示標章
                if currentItem.mediaType == .video {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 54, height: 54)
                        Image(systemName: "play.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .offset(x: 2)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedMediaIDForViewer = currentItem.id
            }
            
            // 頂部多圖指示條 (如: 1/3)
            if attachedItems.count > 1 {
                VStack {
                    HStack {
                        Spacer()
                        Text("\(activeIndex + 1)/\(attachedItems.count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(12)
                            .padding(12)
                    }
                    Spacer()
                }
                
                // 左右切換箭頭按鈕
                HStack {
                    if activeIndex > 0 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentMediaIndex = max(0, activeIndex - 1)
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 12)
                    }
                    
                    Spacer()
                    
                    if activeIndex < attachedItems.count - 1 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentMediaIndex = min(attachedItems.count - 1, activeIndex + 1)
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 12)
                    }
                }
                .frame(maxHeight: .infinity)
                
                // 底部指示點
                HStack(spacing: 6) {
                    ForEach(0..<attachedItems.count, id: \.self) { idx in
                        Circle()
                            .fill(idx == activeIndex ? Color.white : Color.white.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .frame(height: 380)
        .clipped()
    }
}
