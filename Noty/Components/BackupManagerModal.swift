import SwiftUI
import SwiftData
import AppKit

/// 本機備份與還原管理彈窗（BackupManagerModal）
/// 支援完整全庫備份、獨立日記匯出、媒體檔案匯出、資料庫快照，以及帶有兩階段安全檢驗的備份還原
public struct BackupManagerModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }) private var mediaItems: [MediaItem]
    @Query(filter: #Predicate<DiaryEntry> { !$0.isDeleted }) private var diaryEntries: [DiaryEntry]
    
    // 操作模式：.export 或 .restore
    @State private var selectedTab: BackupMode = .export
    @State private var diaryFormat: DiaryExportFormat = .markdown
    
    // 狀態提示
    @State private var isProcessing: Bool = false
    @State private var statusMessage: String? = nil
    @State private var isErrorMessage: Bool = false
    
    // 還原待確認狀態
    @State private var pendingRestoreURL: URL? = nil
    @State private var pendingManifest: BackupManifest? = nil
    @State private var isShowingRestoreConfirmAlert: Bool = false
    
    public enum BackupMode: String, CaseIterable, Identifiable {
        case export = "Export Backup"
        case restore = "Restore Backup"
        public var id: String { rawValue }
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // 頂部導航
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "externaldrive.badge.timemachine")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Backup & Restore")
                            .font(.headline)
                        Text("Noty 本機資料封裝、匯出與安全還原")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // 模式切換（Export vs Restore）
            Picker("Mode", selection: $selectedTab) {
                ForEach(BackupMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // 狀態回報提示
            if let msg = statusMessage {
                HStack(spacing: 8) {
                    Image(systemName: isErrorMessage ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(isErrorMessage ? .red : .green)
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isErrorMessage ? .red : .primary)
                    Spacer()
                }
                .padding(10)
                .background((isErrorMessage ? Color.red : Color.green).opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 24)
                .padding(.top, 10)
            }
            
            // 主體區域
            if selectedTab == .export {
                exportSectionView
            } else {
                restoreSectionView
            }
            
            Spacer()
        }
        .frame(width: 540, height: 500)
        // 還原危險確認警報
        .alert(
            "⚠️ 確認從備份還原？",
            isPresented: $isShowingRestoreConfirmAlert,
            presenting: pendingManifest
        ) { manifest in
            Button("取消", role: .cancel) {
                pendingRestoreURL = nil
                pendingManifest = nil
            }
            Button("確認還原", role: .destructive) {
                executeRestore()
            }
        } message: { manifest in
            Text("""
            選取的備份包含：
            • 備份日期：\(formatDate(manifest.backupDate))
            • 照片數量：\(manifest.photoCount >= 0 ? "\(manifest.photoCount)" : "未載明")
            • 影片數量：\(manifest.videoCount >= 0 ? "\(manifest.videoCount)" : "未載明")
            • 日記數量：\(manifest.diaryCount >= 0 ? "\(manifest.diaryCount)" : "未載明")

            【安全防護機制】
            還原操作將以備份資料替換現有資料庫與媒體庫。
            為避免誤觸或資料損失，Noty 將在執行還原前自動在 Library/Backups 目錄建立一份「現狀緊急安全快照」，您隨時可依需要回退。
            
            您確定要立即還原此備份嗎？
            """)
        }
    }
    
    // MARK: - 匯出選項視圖
    private var exportSectionView: some View {
        VStack(spacing: 14) {
            // 1. 完整備份 (Full Backup)
            exportOptionCard(
                title: "建立全庫完整備份 (Full Backup)",
                subtitle: "打包所有照片、影片、日記與資料庫，產生標準 Noty 備份包",
                icon: "archivebox.fill",
                color: .accentColor,
                buttonTitle: "建立完整備份..."
            ) {
                createFullBackup()
            }
            
            // 2. 匯出日記 (Export Diaries)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "book.pages.fill")
                        .foregroundColor(.orange)
                    Text("匯出日記 (Export Diaries)")
                        .font(.headline)
                    Spacer()
                    Picker("Format", selection: $diaryFormat) {
                        ForEach(DiaryExportFormat.allCases) { fmt in
                            Text(fmt.rawValue).tag(fmt)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 170)
                }
                
                Text("將共 \(diaryEntries.count) 篇日記個別轉存為 Markdown 檔或 JSON 格式，保留標籤與心情資訊")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Spacer()
                    Button("匯出日記資料夾...") {
                        exportDiaries()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            .padding(.horizontal, 24)
            
            // 3. 匯出媒體 (Export Media)
            exportOptionCard(
                title: "匯出照片與影片 (Export Media)",
                subtitle: "將沙盒內的 \(mediaItems.count) 個原始媒體檔案複製至外部自訂資料夾",
                icon: "photo.stack.fill",
                color: .purple,
                buttonTitle: "匯出媒體檔案..."
            ) {
                exportMedia()
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - 還原選項視圖
    private var restoreSectionView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                Text("從先前備份還原資料庫")
                    .font(.headline)
                
                Text("選擇以前建立的 Noty 備份包（Noty_FullBackup_... 資料夾）。系統會在確認還原前完整檢驗備份內容，並先自動備份當前資料。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 30)
            
            Button {
                selectBackupAndInspect()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.gearshape")
                    Text("選取備份資料夾並驗證...")
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    private func exportOptionCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Spacer()
                Button(buttonTitle, action: action)
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1))
        .padding(.horizontal, 24)
    }
    
    // MARK: - 匯出邏輯實作
    private func createFullBackup() {
        let panel = NSOpenPanel()
        panel.title = "選擇要存放完整備份的目標位置"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        guard panel.runModal() == .OK, let targetURL = panel.url else { return }
        
        isProcessing = true
        statusMessage = "正在建立完整備份..."
        isErrorMessage = false
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let photoCount = mediaItems.filter { $0.mediaType == .image }.count
                let videoCount = mediaItems.filter { $0.mediaType == .video }.count
                let diaryCount = diaryEntries.count
                
                let backupURL = try BackupService.shared.createFullBackup(
                    to: targetURL,
                    photoCount: photoCount,
                    videoCount: videoCount,
                    diaryCount: diaryCount
                )
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.isErrorMessage = false
                    self.statusMessage = "完整備份成功！存放於：\(backupURL.lastPathComponent)"
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.isErrorMessage = true
                    self.statusMessage = "備份失敗：\(error.localizedDescription)"
                }
            }
        }
    }
    
    private func exportDiaries() {
        let panel = NSOpenPanel()
        panel.title = "選擇要存放日記的目標位置"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        guard panel.runModal() == .OK, let targetURL = panel.url else { return }
        
        isProcessing = true
        statusMessage = "正在匯出日記..."
        isErrorMessage = false
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let exportURL = try BackupService.shared.exportDiaries(
                    entries: self.diaryEntries,
                    to: targetURL,
                    format: self.diaryFormat
                )
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.isErrorMessage = false
                    self.statusMessage = "成功匯出 \(self.diaryEntries.count) 篇日記至 \(exportURL.lastPathComponent)"
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.isErrorMessage = true
                    self.statusMessage = "日記匯出失敗：\(error.localizedDescription)"
                }
            }
        }
    }
    
    private func exportMedia() {
        let panel = NSOpenPanel()
        panel.title = "選擇要匯出媒體的目標位置"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        guard panel.runModal() == .OK, let targetURL = panel.url else { return }
        
        isProcessing = true
        statusMessage = "正在匯出媒體檔案..."
        isErrorMessage = false
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let exportURL = try BackupService.shared.exportMedia(
                    items: self.mediaItems,
                    to: targetURL
                )
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.isErrorMessage = false
                    self.statusMessage = "成功匯出媒體檔案至 \(exportURL.lastPathComponent)"
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.isErrorMessage = true
                    self.statusMessage = "媒體匯出失敗：\(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - 還原邏輯實作（先驗證並顯示確認視窗）
    private func selectBackupAndInspect() {
        let panel = NSOpenPanel()
        panel.title = "選取 Noty 備份資料夾"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        guard panel.runModal() == .OK, let folderURL = panel.url else { return }
        
        do {
            let manifest = try BackupService.shared.inspectBackup(at: folderURL)
            self.pendingRestoreURL = folderURL
            self.pendingManifest = manifest
            self.isShowingRestoreConfirmAlert = true
        } catch {
            self.isErrorMessage = true
            self.statusMessage = "無效的備份：\(error.localizedDescription)"
        }
    }
    
    private func executeRestore() {
        guard let backupURL = pendingRestoreURL else { return }
        isProcessing = true
        statusMessage = "正在安全還原資料庫與媒體檔案..."
        isErrorMessage = false
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try BackupService.shared.restoreFromBackup(at: backupURL)
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.isErrorMessage = false
                    self.statusMessage = "資料還原成功！系統已重載最新資料庫。"
                    self.pendingRestoreURL = nil
                    self.pendingManifest = nil
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.isErrorMessage = true
                    self.statusMessage = "還原失敗：\(error.localizedDescription)"
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}
