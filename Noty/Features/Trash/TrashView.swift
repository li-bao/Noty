import SwiftUI
import SwiftData

/// 垃圾桶視圖（Trash View）
/// 實現安全回收機制：軟刪除保護，僅在使用者確認清空時才真正執行本機檔案與資料庫實體刪除
public struct TrashView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<MediaItem> { $0.isDeleted }, sort: \MediaItem.deletedAt, order: .reverse)
    private var deletedMediaItems: [MediaItem]
    @Query(filter: #Predicate<DiaryEntry> { $0.isDeleted }, sort: \DiaryEntry.deletedAt, order: .reverse)
    private var deletedDiaryEntries: [DiaryEntry]
    
    @State private var showingEmptyConfirmation = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bin")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text("Trash")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                
                if !deletedMediaItems.isEmpty || !deletedDiaryEntries.isEmpty {
                    Button(role: .destructive) {
                        showingEmptyConfirmation = true
                    } label: {
                        Label("Empty Trash", systemImage: "trash.fill")
                    }
                    .buttonStyle(.notyDestructive(height: 28))
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 14)
            
            Divider()
                .padding(.horizontal, 28)
            
            if deletedMediaItems.isEmpty && deletedDiaryEntries.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "trash.slash")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("Trash is Empty")
                        .font(.headline)
                    Text("Deleted photos, videos, and diaries stay safely here until you explicitly empty the trash.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if !deletedMediaItems.isEmpty {
                            Text("Deleted Media (\(deletedMediaItems.count))")
                                .font(.headline)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 18)], spacing: 18) {
                                ForEach(deletedMediaItems) { item in
                                    VStack(alignment: .leading, spacing: 6) {
                                        ZStack(alignment: .topTrailing) {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.secondary.opacity(0.12))
                                                .aspectRatio(1, contentMode: .fit)
                                            
                                            Image(systemName: item.mediaType == .video ? "video.slash" : "photo.slash")
                                                .font(.system(size: 34))
                                                .foregroundColor(.secondary)
                                            
                                            Button(action: {
                                                restoreMediaItem(item)
                                            }) {
                                                Text("Restore")
                                                    .font(.caption2.bold())
                                                    .padding(6)
                                                    .background(.ultraThinMaterial)
                                                    .cornerRadius(6)
                                            }
                                            .buttonStyle(.plain)
                                            .padding(8)
                                        }
                                        
                                        Text(item.originalFileName)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        
                        if !deletedDiaryEntries.isEmpty {
                            Text("Deleted Diaries (\(deletedDiaryEntries.count))")
                                .font(.headline)
                            
                            ForEach(deletedDiaryEntries) { entry in
                                HStack {
                                    Text(entry.mood)
                                        .font(.title3)
                                        .fixedSize()
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.title)
                                            .font(.subheadline.bold())
                                        Text(entry.content)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Button("Restore") {
                                        restoreDiaryEntry(entry)
                                    }
                                    .buttonStyle(.notySecondary(height: 24))
                                }
                                .padding(12)
                                .background(Color.secondary.opacity(0.06))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(28)
                }
            }
        }
        .confirmationDialog(
            "Are you sure you want to permanently empty the trash?",
            isPresented: $showingEmptyConfirmation,
            titleVisibility: .visible
        ) {
            Button("Permanently Delete All Items", role: .destructive) {
                permanentlyEmptyTrash()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove \(deletedMediaItems.count) media files from your Mac's disk and delete \(deletedDiaryEntries.count) diaries. This action cannot be undone.")
        }
    }
    
    private func restoreMediaItem(_ item: MediaItem) {
        item.isDeleted = false
        item.deletedAt = nil
        try? modelContext.save()
    }
    
    private func restoreDiaryEntry(_ entry: DiaryEntry) {
        entry.isDeleted = false
        entry.deletedAt = nil
        try? modelContext.save()
    }
    
    private func permanentlyEmptyTrash() {
        // 1. 永久刪除磁碟上的實體媒體檔案
        for item in deletedMediaItems {
            StorageService.shared.permanentlyDeleteFile(at: item.relativePath)
            modelContext.delete(item)
        }
        
        // 2. 刪除日記紀錄
        for entry in deletedDiaryEntries {
            modelContext.delete(entry)
        }
        
        try? modelContext.save()
    }
}
