import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

/// 藝廊頂部回憶插圖標章（忠實呼應手繪稿中照片框內站立的人偶與太陽插圖）
public struct GalleryIllustrationBadge: View {
    public init() {}
    
    public var body: some View {
        ZStack {
            // 拍立得風格照片外框
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(width: 46, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.primary.opacity(0.35), lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1.5)
            
            // 相框內微天空背景與人偶太陽
            HStack(spacing: 5) {
                // 人偶 (stick figure)
                Image(systemName: "figure.stand")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                // 右上角太陽 (sun)
                VStack {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Spacer()
                }
                .frame(height: 20)
            }
            .padding(.horizontal, 4)
        }
    }
}

/// 藝廊篩選類別擴充（Phase 9.5 智慧分類）
public enum GalleryCategoryFilter: String, CaseIterable, Identifiable {
    case all = "All Memories"
    case photos = "Photos"
    case videos = "Videos"
    case favorites = "Favorites"
    case important = "Important"
    case recentlyAdded = "Recently Added"
    case thisMonth = "This Month"
    case thisYear = "This Year"
    case unsorted = "Unsorted"
    
    public var id: String { rawValue }
}

/// 藝廊相簿主畫面
public struct GalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }, sort: \MediaItem.capturedAt, order: .reverse)
    private var allMediaItems: [MediaItem]
    
    // UI 控制狀態
    @State private var showingFileImporter = false
    @State private var categoryFilter: GalleryCategoryFilter = .all
    @State private var hoveredItemId: UUID?
    @State private var selectedViewerID: UUID?
    
    // 多選與批次操作狀態
    @State private var isSelectionMode: Bool = false
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var showingBatchTrashConfirm: Bool = false
    
    public init() {}
    
    // 依使用者條件篩選的媒體項目清單
    private var filteredItems: [MediaItem] {
        var items = allMediaItems
        
        // 1. 智慧分類篩選 (Smart Albums)
        switch categoryFilter {
        case .all:
            break
        case .photos:
            items = items.filter { $0.mediaType == .image }
        case .videos:
            items = items.filter { $0.mediaType == .video }
        case .favorites:
            items = items.filter { $0.isFavorite }
        case .important:
            items = items.filter { $0.isImportant }
        case .recentlyAdded:
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            items = items.filter { $0.importedAt >= sevenDaysAgo }
        case .thisMonth:
            let now = Date()
            items = items.filter { Calendar.current.isDate($0.capturedAt, equalTo: now, toGranularity: .month) }
        case .thisYear:
            let now = Date()
            items = items.filter { Calendar.current.isDate($0.capturedAt, equalTo: now, toGranularity: .year) }
        case .unsorted:
            items = items.filter { $0.tags.isEmpty && $0.albumIDs.isEmpty }
        }
        
        // 2. 搜尋關鍵字比對（檔名、描述、標籤）
        if !appState.searchText.isEmpty {
            let query = appState.searchText.lowercased()
            items = items.filter { item in
                item.originalFileName.lowercased().contains(query) ||
                item.caption.lowercased().contains(query) ||
                item.tags.contains(where: { $0.lowercased().contains(query) })
            }
        }
        
        // 3. 排序（預設拍攝日期，若無拍攝日期則依匯入日期）
        items.sort { a, b in
            let dateA = a.capturedAt
            let dateB = b.capturedAt
            if appState.isAscendingOrder {
                return dateA < dateB
            } else {
                return dateA > dateB
            }
        }
        
        return items
    }
    
    // 按日期（年月日）分組結構
    private var dateGroupedSections: [(dateString: String, items: [MediaItem])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "yyyy/M/d (E)"
        
        var groups: [String: [MediaItem]] = [:]
        var orderTracker: [String: Date] = [:]
        
        for item in filteredItems {
            let key = formatter.string(from: item.capturedAt)
            if groups[key] == nil {
                groups[key] = []
                orderTracker[key] = item.capturedAt
            }
            groups[key]?.append(item)
        }
        
        let sortedKeys = groups.keys.sorted { key1, key2 in
            let d1 = orderTracker[key1] ?? Date.distantPast
            let d2 = orderTracker[key2] ?? Date.distantPast
            return appState.isAscendingOrder ? (d1 < d2) : (d1 > d2)
        }
        
        return sortedKeys.map { key in
            (dateString: key, items: groups[key] ?? [])
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 頂部導航指示列
            topHeaderSection
            
            // MARK: - 控制列（日期顯示、搜尋框、分類篩選、排序切換、多選模式）
            toolbarControlSection
            
            // MARK: - 批次操作浮動列（在選取模式下展開）
            if isSelectionMode {
                batchActionToolbar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // MARK: - Undo 撤銷橫幅（移入垃圾桶後提供即時復原）
            if appState.undoActionAvailable {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundColor(.accentColor)
                    Text(appState.undoActionMessage)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                    Spacer()
                    Button("Undo") {
                        undoTrash()
                    }
                    .buttonStyle(.notySecondary(height: 24))
                    
                    Button {
                        appState.clearUndo()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.notyIcon(size: 20))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .padding(.horizontal, 28)
            }
            
            Divider()
                .padding(.horizontal, 28)
            
            // MARK: - 主要相簿內容區（空狀態或分組網格）
            if filteredItems.isEmpty {
                GalleryEmptyView(
                    onUpload: { appState.isUploadSheetPresented = true },
                    onOpenFile: { showingFileImporter = true }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                groupedMediaScrollView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.image, .movie],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result: result)
        }
        // 全螢幕高解析大圖/影片預覽燈箱
        .sheet(isPresented: Binding(
            get: { selectedViewerID != nil },
            set: { if !$0 { selectedViewerID = nil } }
        )) {
            MediaViewerModal(items: filteredItems, currentItemID: $selectedViewerID)
        }
        .alert("Move \(selectedItemIDs.count) items to Trash?", isPresented: $showingBatchTrashConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                batchMoveToTrash()
            }
        } message: {
            Text("These items will be moved to the Trash. You can restore them anytime.")
        }
    }
    
    // MARK: - 頂部標題區
    private var topHeaderSection: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("You are now at")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 10) {
                    Text("Gallery")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .underline(color: .accentColor.opacity(0.85))
                        .layoutPriority(1)
                    
                    GalleryIllustrationBadge()
                }
            }
            .layoutPriority(1)
            
            Spacer(minLength: 12)
            
            // 智慧分類膠囊滑動篩選器（純滑鼠滾輪橫向滑動，極簡 Liquid Glass 膠囊風格，無多餘箭頭）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(GalleryCategoryFilter.allCases) { cat in
                        Button {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                categoryFilter = cat
                            }
                        } label: {
                            Text(cat.rawValue)
                                .font(.system(size: 11, weight: categoryFilter == cat ? .bold : .medium, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .foregroundColor(categoryFilter == cat ? .accentColor : .secondary)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .liquidCapsule(isActive: categoryFilter == cat, isInteractive: true)
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 2)
            }
            .horizontalWheelScroll()
            .frame(maxWidth: 580)
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }
    
    // MARK: - 工具列與搜尋列
    private var toolbarControlSection: some View {
        HStack(spacing: 12) {
            // 搜尋關鍵字輸入框
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Search memories, captions, tags...", text: Bindable(appState).searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !appState.searchText.isEmpty {
                    Button(action: { appState.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(8)
            .frame(maxWidth: 260)
            
            Spacer()
            
            // 升降排序切換
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.isAscendingOrder = true
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(appState.isAscendingOrder ? .accentColor : .secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("依日期升冪排序（最舊優先）")
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.isAscendingOrder = false
                    }
                }) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(!appState.isAscendingOrder ? .accentColor : .secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("依日期降冪排序（最新優先）")
            }
            
            // 多選模式切換按鈕
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        selectedItemIDs.removeAll()
                    }
                }
            }) {
                Label(isSelectionMode ? "Done" : "Select", systemImage: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isSelectionMode ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                    .foregroundColor(isSelectionMode ? .accentColor : .primary)
                    .cornerRadius(7)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
    }
    
    // MARK: - 批次操作工具列
    private var batchActionToolbar: some View {
        HStack(spacing: 14) {
            Text("\(selectedItemIDs.count) items selected")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // 全選當前頁面所有項目
            Button("Select All") {
                selectedItemIDs = Set(filteredItems.map(\.id))
            }
            .font(.caption)
            .buttonStyle(.plain)
            
            // 批次加入收藏
            Button {
                batchAddToFavorites()
            } label: {
                Label("Favorite", systemImage: "heart.fill")
                    .font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .disabled(selectedItemIDs.isEmpty)
            
            // 批次加入相簿
            Button {
                batchAddToAlbum()
            } label: {
                Label("Add to Album...", systemImage: "rectangle.stack.badge.plus")
                    .font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .disabled(selectedItemIDs.isEmpty)
            
            // 批次匯出
            Button {
                batchExportMedia()
            } label: {
                Label("Export...", systemImage: "square.and.arrow.up")
                    .font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .disabled(selectedItemIDs.isEmpty)
            
            // 批次移入垃圾桶
            Button(role: .destructive) {
                showingBatchTrashConfirm = true
            } label: {
                Label("Move to Trash", systemImage: "trash.fill")
                    .font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .disabled(selectedItemIDs.isEmpty)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.08))
    }
    
    // MARK: - 按日期分組滾動網格
    private var groupedMediaScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(dateGroupedSections, id: \.dateString) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        // 日期分組標頭
                        HStack(spacing: 8) {
                            Text(section.dateString)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("• \(section.items.count)")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if isSelectionMode {
                                Button("Select Day") {
                                    for item in section.items {
                                        selectedItemIDs.insert(item.id)
                                    }
                                }
                                .font(.caption2)
                                .buttonStyle(.plain)
                                .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        // 當天媒體網格
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 16)],
                            spacing: 16
                        ) {
                            ForEach(section.items) { item in
                                MediaThumbnailCard(
                                    item: item,
                                    isHovered: hoveredItemId == item.id,
                                    isSelectionMode: isSelectionMode,
                                    isSelected: selectedItemIDs.contains(item.id),
                                    onTap: {
                                        if isSelectionMode {
                                            toggleSelection(item.id)
                                        } else {
                                            selectedViewerID = item.id
                                        }
                                    },
                                    onToggleFavorite: {
                                        item.isFavorite.toggle()
                                        try? modelContext.save()
                                    },
                                    onMoveToTrash: {
                                        item.isDeleted = true
                                        item.deletedAt = Date()
                                        try? modelContext.save()
                                    }
                                )
                                .onHover { hovering in
                                    if !reduceMotion {
                                        withAnimation(.easeInOut(duration: 0.16)) {
                                            hoveredItemId = hovering ? item.id : nil
                                        }
                                    } else {
                                        hoveredItemId = hovering ? item.id : nil
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
    }
    
    // MARK: - 批次動作邏輯
    private func toggleSelection(_ id: UUID) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }
    
    private func batchAddToFavorites() {
        for item in allMediaItems where selectedItemIDs.contains(item.id) {
            item.isFavorite = true
        }
        try? modelContext.save()
        ToastService.shared.show("Added \(selectedItemIDs.count) items to Favorites", icon: "heart.fill")
        selectedItemIDs.removeAll()
        isSelectionMode = false
    }
    
    private func batchAddToAlbum() {
        let picked = allMediaItems.filter { selectedItemIDs.contains($0.id) }
        appState.itemsToAddToAlbum = picked
        appState.isAddToAlbumPresented = true
        selectedItemIDs.removeAll()
        isSelectionMode = false
    }
    
    private func batchExportMedia() {
        let picked = allMediaItems.filter { selectedItemIDs.contains($0.id) }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export Memories Here"
        
        if panel.runModal() == .OK, let targetURL = panel.url {
            do {
                let count = try ExportService.shared.exportMedia(items: picked, to: targetURL)
                ToastService.shared.show("Successfully exported \(count) memories", icon: "square.and.arrow.up")
            } catch {
                ToastService.shared.show("Export failed: \(error.localizedDescription)", isSuccess: false)
            }
        }
        selectedItemIDs.removeAll()
        isSelectionMode = false
    }
    
    private func batchMoveToTrash() {
        var trashedIDs: [UUID] = []
        var protectedCount = 0
        for item in allMediaItems where selectedItemIDs.contains(item.id) {
            if item.isProtected {
                protectedCount += 1
                continue
            }
            item.isDeleted = true
            item.deletedAt = Date()
            trashedIDs.append(item.id)
        }
        try? modelContext.save()
        if !trashedIDs.isEmpty {
            appState.recordTrashAction(mediaIDs: trashedIDs, message: "已將 \(trashedIDs.count) 個回憶移入垃圾桶")
            ToastService.shared.show("Moved \(trashedIDs.count) memories to Trash", icon: "trash")
        }
        if protectedCount > 0 {
            ToastService.shared.show("\(protectedCount) items are protected and were kept", icon: "shield.fill")
        }
        selectedItemIDs.removeAll()
        isSelectionMode = false
    }
    
    private func undoTrash() {
        for id in appState.lastTrashedMediaItemIDs {
            if let item = allMediaItems.first(where: { $0.id == id }) {
                item.isDeleted = false
                item.deletedAt = nil
            }
        }
        try? modelContext.save()
        appState.clearUndo()
        ToastService.shared.show("Restored memories from Trash", icon: "arrow.uturn.backward")
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        if case .success(let urls) = result {
            appState.isImportProgressModalPresented = true
            Task { @MainActor in
                await MediaImportService.shared.importFiles(
                    urls: urls,
                    modelContext: modelContext
                )
            }
        }
    }
}

/// 藝廊單張縮圖卡片（支援多選 Checkbox、影片標記與縮圖快取）
public struct MediaThumbnailCard: View {
    public let item: MediaItem
    public let isHovered: Bool
    public let isSelectionMode: Bool
    public let isSelected: Bool
    public let onTap: () -> Void
    public let onToggleFavorite: () -> Void
    public let onMoveToTrash: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // 媒體縮圖容器
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.1))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Group {
                                if !item.fileExistsOnDisk {
                                    VStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.title2)
                                            .foregroundColor(.orange)
                                        Text("Missing on Disk")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.secondary)
                                    }
                                } else if let thumb = ThumbnailService.shared.loadCachedThumbnail(for: item.storedFileName) {
                                    Image(nsImage: thumb)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else if item.mediaType == .image, let image = NSImage(contentsOf: item.fileURL) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    VStack(spacing: 6) {
                                        Image(systemName: item.mediaType == .video ? "video.fill" : "photo.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(isHovered ? .accentColor : .secondary.opacity(0.6))
                                        Text(item.originalFileName)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .padding(.horizontal, 8)
                                    }
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.black.opacity(isHovered ? 0.14 : 0.03), radius: isHovered ? 6 : 2, x: 0, y: isHovered ? 3 : 1)
                    
                    // 影片播放標章
                    if item.mediaType == .video {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8))
                            if item.durationSeconds > 0 {
                                Text(formatDuration(item.durationSeconds))
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            } else {
                                Text("Video")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(6)
                    }
                }
                
                // 右上角浮動按鈕：多選 Checkbox 或 收藏 Heart
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isSelected ? .accentColor : .white)
                        .background(Circle().fill(isSelected ? Color.white : Color.black.opacity(0.4)))
                        .padding(8)
                } else {
                    Button(action: onToggleFavorite) {
                        Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 13))
                            .foregroundColor(item.isFavorite ? .red : .white)
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }
            }
            .scaleEffect(isHovered && !reduceMotion ? 1.025 : 1.0)
            
            // 下方資訊列（檔名與格式）
            HStack {
                Text(item.originalFileName)
                    .font(.caption.bold())
                    .lineLimit(1)
                Spacer()
                Text(item.fileFormat.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button(action: onToggleFavorite) {
                Label(item.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: item.isFavorite ? "heart.slash" : "heart")
            }
            
            Button {
                if item.fileExistsOnDisk {
                    NSWorkspace.shared.selectFile(item.fileURL.path, inFileViewerRootedAtPath: item.fileURL.deletingLastPathComponent().path)
                }
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            
            Divider()
            
            Button(role: .destructive, action: onMoveToTrash) {
                Label("Move to Trash", systemImage: "trash")
            }
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
