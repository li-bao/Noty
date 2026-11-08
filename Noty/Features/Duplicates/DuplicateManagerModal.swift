import SwiftUI
import SwiftData

/// 重複與相似照片管理彈窗
public struct DuplicateManagerModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }) private var allMedia: [MediaItem]
    
    @State private var selectedTab: DuplicateTab = .exact
    @State private var exactGroups: [DuplicateDetectionService.ExactDuplicateGroup] = []
    @State private var similarPairs: [DuplicateDetectionService.SimilarPhotoPair] = []
    @State private var isScanning = true
    
    enum DuplicateTab: String, CaseIterable, Identifiable {
        case exact = "Exact Matches (SHA-256)"
        case similar = "Visually Similar (dHash)"
        var id: String { rawValue }
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 頂部工具列
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Duplicate Detection")
                        .font(.title2.bold())
                    Text("Review identical or visually similar photos to free up storage.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("Mode", selection: $selectedTab) {
                    ForEach(DuplicateTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 12)
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
            
            Divider()
            
            if isScanning {
                VStack(spacing: 14) {
                    ProgressView()
                    Text("Analyzing hashes and perceptual similarity...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                contentSection
            }
        }
        .frame(width: 820, height: 600)
        .task {
            scanDuplicates()
        }
    }
    
    @ViewBuilder
    private var contentSection: some View {
        if selectedTab == .exact {
            if exactGroups.isEmpty {
                emptyStateView(icon: "checkmark.seal.fill", title: "No Exact Duplicates", subtitle: "All photos and videos have unique SHA-256 fingerprints.")
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(exactGroups) { group in
                            exactGroupCard(group: group)
                        }
                    }
                    .padding(20)
                }
            }
        } else {
            if similarPairs.isEmpty {
                emptyStateView(icon: "sparkles", title: "No Visually Similar Photos", subtitle: "No photos share near-identical compositions.")
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(similarPairs) { pair in
                            similarPairCard(pair: pair)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
    
    @ViewBuilder
    private func exactGroupCard(group: DuplicateDetectionService.ExactDuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Exact Duplicate (\(group.items.count) files)", systemImage: "doc.on.doc.fill")
                    .font(.headline)
                    .foregroundColor(.accentColor)
                
                Spacer()
                
                Text("Potential Savings: \(ByteCountFormatter.string(fromByteCount: group.recoverableSize, countStyle: .file))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(group.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            ZStack(alignment: .topTrailing) {
                                AsyncThumbnailView(storedFileName: item.storedFileName, isVideo: item.mediaType == .video)
                                    .frame(width: 140, height: 110)
                                    .cornerRadius(8)
                            }
                            
                            Text(item.originalFileName)
                                .font(.caption.bold())
                                .lineLimit(1)
                                .frame(width: 140, alignment: .leading)
                            
                            Text("\(item.pixelWidth)×\(item.pixelHeight) • \(item.formattedFileSize)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Button(role: .destructive) {
                                trashItem(item)
                            } label: {
                                Label("Move to Trash", systemImage: "trash")
                                    .font(.caption2)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func similarPairCard(pair: DuplicateDetectionService.SimilarPhotoPair) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Visually Similar (\(pair.similarityPercentage)% match)", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                    .foregroundColor(.purple)
                
                Spacer()
                
                Text("dHash Hamming Distance: \(pair.hammingDistance)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                // Photo 1
                itemPreviewColumn(item: pair.item1) {
                    trashItem(pair.item1)
                }
                
                Divider()
                
                // Photo 2
                itemPreviewColumn(item: pair.item2) {
                    trashItem(pair.item2)
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func itemPreviewColumn(item: MediaItem, onTrash: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            AsyncThumbnailView(storedFileName: item.storedFileName, isVideo: false)
                .frame(width: 110, height: 90)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.originalFileName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                
                Text("\(item.pixelWidth)×\(item.pixelHeight)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(item.formattedFileSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(role: .destructive, action: onTrash) {
                    Label("Trash", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.accentColor.opacity(0.8))
            
            Text(title)
                .font(.title3.bold())
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func scanDuplicates() {
        Task.detached(priority: .userInitiated) {
            let exact = DuplicateDetectionService.shared.findExactDuplicates(in: allMedia)
            let similar = DuplicateDetectionService.shared.findSimilarPhotos(in: allMedia)
            
            await MainActor.run {
                self.exactGroups = exact
                self.similarPairs = similar
                self.isScanning = false
            }
        }
    }
    
    private func trashItem(_ item: MediaItem) {
        item.isDeleted = true
        item.deletedAt = Date()
        try? modelContext.save()
        scanDuplicates()
        ToastService.shared.show("Moved \"\(item.originalFileName)\" to Trash", icon: "trash")
    }
}
