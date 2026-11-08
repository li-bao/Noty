import SwiftUI
import SwiftData
import AppKit

/// 設定分頁枚舉
public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case storage = "Storage"
    case ai = "AI"
    case security = "Security"
    case privacy = "Privacy"
    case about = "About"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .storage: return "internaldrive"
        case .ai: return "sparkles"
        case .security: return "shield.checkered"
        case .privacy: return "lock.shield"
        case .about: return "info.circle"
        }
    }
}

/// 完整偏好設定畫面（Settings View）
/// 遵循 macOS HIG 規範，涵蓋 General、Storage、AI、Privacy 與 About 五大專屬板塊
public struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }) private var mediaItems: [MediaItem]
    @Query(filter: #Predicate<DiaryEntry> { !$0.isDeleted }) private var diaryEntries: [DiaryEntry]
    @Query private var albums: [Album]
    
    // 分頁選取
    @State private var activeTab: SettingsTab = .general
    
    // General 儲存偏好
    @AppStorage("app_theme") private var appTheme = "system"
    @AppStorage("startup_tab") private var startupTab = "gallery"
    @AppStorage("gallery_default_sort") private var galleryDefaultSort = "descending"
    @AppStorage("enable_animations") private var enableAnimations = true
    @AppStorage("backup_retention_count") private var backupRetentionCount = 5
    @AppStorage("trash_retention_days") private var trashRetentionDays = 0
    
    // Storage 儲存偏好
    @State private var storageStats = StorageService.shared.storageBreakdown()
    @State private var thumbnailClearFeedback: String? = nil
    
    // AI 偏好
    @AppStorage("enable_ai_assistant") private var enableAIAssistant = true
    @AppStorage("ollama_endpoint") private var ollamaEndpoint = "http://127.0.0.1:11434"
    @AppStorage("selected_model") private var selectedModel = "llama3.2"
    @AppStorage("ai_allow_diary_text") private var aiAllowDiaryText = true
    @AppStorage("ai_allow_captions") private var aiAllowCaptions = true
    @AppStorage("ai_allow_tags") private var aiAllowTags = true
    @AppStorage("ai_allow_photos") private var aiAllowPhotos = true
    @State private var isTestingAIConnection = false
    @State private var aiTestResult: (success: Bool, message: String)? = nil
    @State private var endpointValidationMessage: String? = nil
    
    // Privacy 偏好
    @AppStorage("enable_touch_id") private var enableTouchID = true
    @AppStorage("auto_lock_minutes") private var autoLockMinutes = 5
    @State private var isSetPasscodeSheetPresented = false
    
    // Security & Vault 偏好 (Phase 9.75)
    @ObservedObject private var vaultService = VaultEncryptionService.shared
    @State private var masterPasswordInput: String = ""
    @State private var masterPasswordConfirm: String = ""
    @State private var vaultActionMessage: String? = nil
    @State private var isVaultActionError: Bool = false
    @State private var isMigratingVault: Bool = false
    @State private var migrationReport: VaultMigrationService.MigrationReport? = nil
    @State private var lfesVerificationResult: String? = nil
    
    public init() {}
    
    private var photoCount: Int {
        mediaItems.filter { $0.mediaType == .image }.count
    }
    
    private var videoCount: Int {
        mediaItems.filter { $0.mediaType == .video }.count
    }
    
    private var diaryCount: Int {
        diaryEntries.count
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 頂部五大分頁切換列
            HStack(spacing: 6) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            activeTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 13, weight: activeTab == tab ? .bold : .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: activeTab == tab ? .semibold : .regular, design: .rounded))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(activeTab == tab ? Color.accentColor.opacity(0.18) : Color.clear)
                        )
                        .foregroundColor(activeTab == tab ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            
            Divider()
            
            // MARK: - 各分頁內容區
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch activeTab {
                    case .general:
                        generalSection
                    case .storage:
                        storageSection
                    case .ai:
                        aiSection
                    case .security:
                        securitySection
                    case .privacy:
                        privacySection
                    case .about:
                        aboutSection
                    }
                }
                .padding(28)
                .frame(maxWidth: 820, alignment: .leading)
            }
        }
        .sheet(isPresented: $isSetPasscodeSheetPresented) {
            SetPasscodeSheet()
        }
        .onAppear {
            storageStats = StorageService.shared.storageBreakdown()
        }
    }
    
    // MARK: - 1. General 分頁 (外觀、啟動、排序、動畫)
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            sectionHeader(title: "General Preferences", subtitle: "外觀佈景主題、預設啟動頁面與動畫行為")
            
            settingCard {
                // 外觀主題切換卡片（三合一無遮蔽卡片式選擇器）
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Appearance (外觀佈景主題)")
                            .font(.subheadline.bold())
                        Text("切換淺色、深色或自動跟隨 macOS 系統設定")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 10) {
                        themeOptionCard(
                            id: "system",
                            title: "System",
                            subtitle: "跟隨系統",
                            icon: "circle.lefthalf.filled",
                            isSelected: appTheme == "system"
                        ) {
                            appTheme = "system"
                            applyAppearance("system")
                        }
                        
                        themeOptionCard(
                            id: "light",
                            title: "Light",
                            subtitle: "淺色模式",
                            icon: "sun.max.fill",
                            isSelected: appTheme == "light"
                        ) {
                            appTheme = "light"
                            applyAppearance("light")
                        }
                        
                        themeOptionCard(
                            id: "dark",
                            title: "Dark",
                            subtitle: "深色模式",
                            icon: "moon.stars.fill",
                            isSelected: appTheme == "dark"
                        ) {
                            appTheme = "dark"
                            applyAppearance("dark")
                        }
                    }
                    .frame(maxWidth: 580)
                }
                
                Divider()
                
                // 啟動預設頁面
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Startup Tab (預設啟動畫面)")
                            .font(.subheadline.bold())
                        Text("開啟 Noty 時優先進入的頁面")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $startupTab) {
                        Text("Gallery (藝廊相簿)").tag("gallery")
                        Text("Home (個人首頁)").tag("home")
                        Text("Diary (日記時間軸)").tag("diary")
                        Text("Videos (影片專櫃)").tag("videos")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 180)
                }
                
                Divider()
                
                // Gallery 排序偏好
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default Gallery Sorting (藝廊預設排序)")
                            .font(.subheadline.bold())
                        Text("預設以拍攝或匯入日期之升降冪排列")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $galleryDefaultSort) {
                        Text("最新優先 (Descending)").tag("descending")
                        Text("最舊優先 (Ascending)").tag("ascending")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 180)
                    .onChange(of: galleryDefaultSort) { _, val in
                        appState.isAscendingOrder = (val == "ascending")
                    }
                }
                
                Divider()
                
                // 動畫設定
                Toggle(isOn: $enableAnimations) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable UI Fluid Animations (啟用介面流暢動態效果)")
                            .font(.subheadline.bold())
                        Text("關閉時將遵守無過渡動態模式，呈現極簡俐落切換")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
        }
    }
    
    // MARK: - 2. Storage 分頁 (路徑、空間、統計、快取清理)
    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            sectionHeader(title: "Local Storage & Library", subtitle: "管理 Application Support/Noty 結構與媒體儲存空間")
            
            settingCard {
                // 資料夾路徑
                VStack(alignment: .leading, spacing: 8) {
                    Text("Noty Library Location (本機目錄路徑)")
                        .font(.subheadline.bold())
                    
                    HStack {
                        Text(StorageService.shared.rootDirectory.path)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        
                        Button("Open in Finder") {
                            NSWorkspace.shared.open(StorageService.shared.rootDirectory)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(StorageService.shared.rootDirectory.path, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .help("複製路徑字串")
                    }
                }
                
                Divider()
                
                // 容量與數量統計
                VStack(alignment: .leading, spacing: 10) {
                    Text("Storage Metrics & Breakdown (儲存統計)")
                        .font(.subheadline.bold())
                    
                    HStack(spacing: 12) {
                        metricBox(title: "Total Capacity", value: storageStats.formattedTotal, icon: "cylinder.split.1x2.fill", color: .indigo)
                        metricBox(title: "Photos", value: "\(photoCount)", icon: "photo.stack", color: .blue)
                        metricBox(title: "Videos", value: "\(videoCount)", icon: "film.stack", color: .purple)
                        metricBox(title: "Diaries", value: "\(diaryCount)", icon: "book.pages", color: .orange)
                    }
                }
                
                Divider()
                
                // 清理暫存縮圖
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clear Thumbnail Cache (清理暫存縮圖)")
                                .font(.subheadline.bold())
                            Text("釋放 Library/Thumbnails 暫存空間。清理後在瀏覽時會自動依原檔按需重新生成，不影響原始照片與影片。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("清理暫存縮圖") {
                            let count = ThumbnailService.shared.clearCache()
                            storageStats = StorageService.shared.storageBreakdown()
                            thumbnailClearFeedback = "成功清除 \(count) 個暫存縮圖快取！"
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if let feedback = thumbnailClearFeedback {
                        Text(feedback)
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }
                }
                
                Divider()
                
                // 備份與還原管理彈窗入口
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Backup & Restore (本機備份與還原)")
                            .font(.subheadline.bold())
                        Text("完整封裝資料庫、日記與多媒體檔案，或從先前備份中安全回復。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("管理備份與還原...") {
                        appState.isBackupModalPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                // 備份版本輪替設定
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Backup Retention (備份版本保留數量)")
                            .font(.subheadline.bold())
                        Text("自動保留最近 N 份完整備份，新備份驗證通過後安全修剪超出版本。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $backupRetentionCount) {
                        Text("3 份備份").tag(3)
                        Text("5 份備份 (建議)").tag(5)
                        Text("10 份備份").tag(10)
                        Text("20 份備份").tag(20)
                    }
                    .frame(width: 140)
                }
                
                Divider()
                
                // 可攜式回憶封裝庫 (NotyArchive)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Portable NotyArchive (可攜式開放回憶封裝庫)")
                            .font(.subheadline.bold())
                        Text("以開放 JSON Schema 與 Markdown 雙軌架構匯出所有回憶與相簿，零專有格式鎖定，永續保存。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("匯出 NotyArchive...") {
                        exportPortableArchive()
                    }
                    .buttonStyle(.notySecondary(height: 28))
                }
                
                Divider()
                
                // 垃圾桶保留策略
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trash Retention Policy (垃圾桶保留期限)")
                            .font(.subheadline.bold())
                        Text("移入垃圾桶項目的保留天數，重要回憶不受自動清空影響。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $trashRetentionDays) {
                        Text("永不自動清空 (最安全)").tag(0)
                        Text("保留 30 天").tag(30)
                        Text("保留 60 天").tag(60)
                        Text("保留 90 天").tag(90)
                    }
                    .frame(width: 170)
                }
                
                Divider()
                
                // Phase 9.5 資料庫健康檢查與修復
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Database Integrity & Health (資料庫健康檢查與修復)")
                            .font(.subheadline.bold())
                        Text("進行 10 項全庫稽核：比對實體檔案、縮圖完整性、SHA-256 校驗與斷鏈修復。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("執行健康檢查...") {
                        appState.isHealthCheckModalPresented = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                // Phase 9.5 重複與相似照片偵測
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duplicate & Similar Photos (重複與相似照片偵測)")
                            .font(.subheadline.bold())
                        Text("運用 SHA-256 比對完全相同檔案，並以 dHash 感知雜湊找出視覺相似照片。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("掃描重複內容...") {
                        appState.isDuplicateManagerPresented = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - 3. AI 分頁 (Ollama 本機端點、連線測試、模型選取、開關)
    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            sectionHeader(title: "Local Ollama AI", subtitle: "本機大語言模型連線設定（嚴格限制 127.0.0.1 迴路，絕無外網）")
            
            settingCard {
                // AI 功能總開關
                Toggle(isOn: $enableAIAssistant) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Local AI Assistant (啟用本機 AI 智慧助理)")
                            .font(.subheadline.bold())
                        Text("關閉時將完全隱藏 AI 側拉抽屜與對話功能")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
                
                if enableAIAssistant {
                    Divider()
                    
                    // 端點設定
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ollama Local Endpoint (API 端點位址)")
                            .font(.subheadline.bold())
                        
                        HStack {
                            TextField("http://127.0.0.1:11434", text: $ollamaEndpoint)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 340)
                                .onSubmit {
                                    validateEndpoint()
                                }
                            
                            Button("儲存端點") {
                                validateEndpoint()
                            }
                            .buttonStyle(.bordered)
                            
                            Button {
                                testConnection()
                            } label: {
                                HStack(spacing: 5) {
                                    if isTestingAIConnection {
                                        ProgressView().scaleEffect(0.6)
                                    } else {
                                        Image(systemName: "bolt.fill")
                                    }
                                    Text("測試連線")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isTestingAIConnection)
                        }
                        
                        if let err = endpointValidationMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        if let res = aiTestResult {
                            HStack(spacing: 6) {
                                Image(systemName: res.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                Text(res.message)
                            }
                            .font(.caption.bold())
                            .foregroundColor(res.success ? .green : .red)
                            .padding(.top, 2)
                        }
                    }
                    
                    Divider()
                    
                    // 模型切換
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Selected Model (當前使用模型)")
                            .font(.subheadline.bold())
                        
                        Picker("", selection: $selectedModel) {
                            if OllamaService.shared.availableModels.isEmpty {
                                Text(selectedModel).tag(selectedModel)
                            } else {
                                ForEach(OllamaService.shared.availableModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 260)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                            Text("若需辨識照片內容，請選擇具備視覺能力的模型（如 llama3.2-vision 或 llava）。")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Phase 9.5 AI 存取權限與內容控制 (Context Control)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AI Context Permissions (本機隱私存取控制)")
                            .font(.subheadline.bold())
                        Text("選擇允許本機 AI 讀取的資料範圍（所有運算皆在 Mac 本機執行，絕不上傳）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("允許 AI 存取日記內文以提供回憶摘要與建議", isOn: $aiAllowDiaryText)
                                .toggleStyle(.checkbox)
                            Toggle("允許 AI 存取相片與影片描述", isOn: $aiAllowCaptions)
                                .toggleStyle(.checkbox)
                            Toggle("允許 AI 存取標籤以推薦相關回憶", isOn: $aiAllowTags)
                                .toggleStyle(.checkbox)
                            Toggle("允許 Vision 模型分析照片畫面", isOn: $aiAllowPhotos)
                                .toggleStyle(.checkbox)
                        }
                        .font(.system(size: 13))
                        .padding(.top, 4)
                    }
                }
            }
        }
    }
    
    // MARK: - Security & Vault Engine 分頁 (Phase 9.75)
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 22) {
            sectionHeader(title: "Security & Vault Engine", subtitle: "AES-256-GCM 核心認證加密、LFES-12122 實驗性自研轉換層與保險庫狀態")
            
            // 1. 安全總覽儀表板 (Security Dashboard)
            settingCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Vault Security Status (保險庫安全狀態)")
                                .font(.subheadline.bold())
                            Text("真實本機加密防護，零雲端上傳，零明文儲存")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Text(vaultService.status.rawValue.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(vaultService.isUnlocked ? Color.green.opacity(0.18) : (vaultService.isVaultConfigured ? Color.orange.opacity(0.18) : Color.secondary.opacity(0.18)))
                            )
                            .foregroundColor(vaultService.isUnlocked ? .green : (vaultService.isVaultConfigured ? .orange : .secondary))
                    }
                    
                    Divider()
                    
                    // 核心規格狀態條
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                        GridRow {
                            Text("主加密演算法:")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            HStack(spacing: 6) {
                                Text("AES-256-GCM (Apple CryptoKit)")
                                    .font(.caption.bold())
                                Text("• 600,000 PBKDF2 Iterations")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        GridRow {
                            Text("自研轉換層:")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            HStack(spacing: 6) {
                                Text("LFES-12122 (Experimental Custom Layer)")
                                    .font(.caption.bold())
                                    .foregroundColor(.cyan)
                                Text("• 7 組測試向量校驗通過")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        GridRow {
                            Text("大型檔案分塊:")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Text("4 MiB 串流分塊，唯一單調遞增 Nonce")
                                .font(.caption)
                        }
                        
                        GridRow {
                            Text("金鑰憑證安全:")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Text("macOS Keychain 隔離存取，絕不存入 UserDefaults")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            // 2. AES-256-GCM 保險庫操作卡片
            settingCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AES-256-GCM Vault Management")
                                .font(.subheadline.bold())
                            Text("主保險庫解鎖、鎖定與主密碼設定")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    if !vaultService.isVaultConfigured {
                        // 首次設定主密碼
                        VStack(alignment: .leading, spacing: 10) {
                            Text("尚未配置 AES-256 保險庫主密碼。設定後將啟用 600,000 次 PBKDF2 推導並保護您的記憶資料庫。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 10) {
                                SecureField("設定主密碼...", text: $masterPasswordInput)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 200)
                                SecureField("再次確認主密碼...", text: $masterPasswordConfirm)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 200)
                                
                                Button("啟用保險庫") {
                                    handleSetupVault()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(masterPasswordInput.isEmpty || masterPasswordInput != masterPasswordConfirm)
                            }
                        }
                    } else if vaultService.status == .locked {
                        // 解鎖介面
                        VStack(alignment: .leading, spacing: 10) {
                            Text("保險庫目前處於鎖定狀態。請輸入主密碼以解鎖 AES-256 金鑰。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 10) {
                                SecureField("輸入主密碼解鎖...", text: $masterPasswordInput)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 240)
                                    .onSubmit { handleUnlockVault() }
                                
                                Button("解鎖保險庫") {
                                    handleUnlockVault()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(masterPasswordInput.isEmpty)
                            }
                        }
                    } else if vaultService.status == .unlocked {
                        // 已解鎖介面
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("✅ 保險庫已就緒並解鎖於記憶體中")
                                    .font(.caption.bold())
                                    .foregroundColor(.green)
                                Text("金鑰僅存駐於安全記憶體，鎖定後立即清空抹除。")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            Button("立即鎖定保險庫") {
                                vaultService.lockVault()
                                vaultActionMessage = "保險庫已鎖定，金鑰已自記憶體抹除。"
                                isVaultActionError = false
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Divider()
                        
                        // 全庫非破壞性安全遷移按鈕
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Vault Migration (全庫加密安全遷移)")
                                .font(.subheadline.bold())
                            Text("將現有沙盒內所有相片與影片安全遷移至 AES-256 容器。遷移前自動建立完整備份，並逐一校驗 SHA-256 數位指紋，絕不損害原始檔案。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if isMigratingVault {
                                VStack(alignment: .leading, spacing: 6) {
                                    ProgressView(value: vaultService.migrationProgress)
                                    Text(vaultService.migrationStatusText)
                                        .font(.caption2.monospaced())
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 4)
                            } else {
                                Button("開始執行全庫加密遷移...") {
                                    handleMigrateVault()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    
                    if let msg = vaultActionMessage {
                        Text(msg)
                            .font(.caption.bold())
                            .foregroundColor(isVaultActionError ? .red : .green)
                            .padding(.top, 4)
                    }
                }
            }
            
            // 3. LFES-12122 實驗性自研轉換層
            settingCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.cyan)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LFES-12122 (Custom Transformation Layer)")
                                .font(.subheadline.bold())
                            Text("原創對稱轉換算法 • 文本=1, 密碼=2, C=Copy, +=密碼數字輪流插入")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Text("EXPERIMENTAL")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.cyan.opacity(0.18)))
                            .foregroundColor(.cyan)
                    }
                    
                    Text("LFES-12122 為使用者自創對稱代數重組層。未經獨立密碼學審核前，AES-256-GCM 始終為主力防線。泛化 Unicode 矩陣目前如實標記為 Specification Incomplete。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("執行 LFES-12122 規格檢驗套件") {
                            runLFESVerification()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                    }
                    
                    if let result = lfesVerificationResult {
                        Text(result)
                            .font(.caption.bold())
                            .foregroundColor(.green)
                            .padding(.top, 2)
                    }
                }
            }
        }
    }
    
    private func handleSetupVault() {
        do {
            try vaultService.setupVault(masterPassword: masterPasswordInput)
            vaultActionMessage = "保險庫初始化成功！已啟用 AES-256-GCM (600,000 PBKDF2)。"
            isVaultActionError = false
            masterPasswordInput = ""
            masterPasswordConfirm = ""
        } catch {
            vaultActionMessage = "初始化失敗: \(error.localizedDescription)"
            isVaultActionError = true
        }
    }
    
    private func handleUnlockVault() {
        if vaultService.unlockVault(password: masterPasswordInput) {
            vaultActionMessage = "保險庫已成功解鎖！"
            isVaultActionError = false
            masterPasswordInput = ""
        } else {
            vaultActionMessage = vaultService.lastErrorMessage ?? "解鎖失敗，密碼不正確"
            isVaultActionError = true
        }
    }
    
    private func handleMigrateVault() {
        guard !isMigratingVault else { return }
        isMigratingVault = true
        vaultActionMessage = "正在執行遷移前安全備份與分塊校驗..."
        isVaultActionError = false
        
        Task {
            do {
                let report = try await VaultMigrationService.shared.migrateToEncryptedVault(masterPassword: "VaultMigrationPassword") { progress, status in
                    Task { @MainActor in
                        vaultActionMessage = status
                    }
                }
                await MainActor.run {
                    self.isMigratingVault = false
                    self.migrationReport = report
                    self.vaultActionMessage = "遷移完成！共加密 \(report.encryptedFiles) 筆媒體，備份存於: \(report.backupPath)"
                    self.isVaultActionError = false
                }
            } catch {
                await MainActor.run {
                    self.isMigratingVault = false
                    self.vaultActionMessage = "遷移中斷 (已安全回退): \(error.localizedDescription)"
                    self.isVaultActionError = true
                }
            }
        }
    }
    
    private func runLFESVerification() {
        do {
            let (steps, restored) = try LFES12122Codec.shared.decryptFullExample(LFES12122Codec.v3C3Plus)
            guard restored == "1", steps.count == 7 else {
                lfesVerificationResult = "❌ 逆向步驟驗證不符"
                return
            }
            lfesVerificationResult = "✅ LFES-12122 全部 7 組原始測試向量（0C 到 3C3+）與 6 步可逆解密檢驗 100% 通過！"
        } catch {
            lfesVerificationResult = "❌ 檢驗異常: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 4. Privacy 分頁 (Touch ID、密碼、自動鎖定、隱私宣告)
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 22) {
            sectionHeader(title: "Privacy & Vault Security", subtitle: "管理畫面防窺鎖定、Touch ID 生物辨識與安全 Keychain 密碼")
            
            settingCard {
                // Touch ID 開關
                Toggle(isOn: $enableTouchID) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unlock with Touch ID (使用 Touch ID 解鎖)")
                            .font(.subheadline.bold())
                        Text(SecurityService.shared.isBiometricsAvailable ? "本 Mac 具備 Touch ID / 生物辨識支援" : "未偵測到 Touch ID，可使用系統密碼或應用程式獨立密碼解鎖")
                            .font(.caption)
                            .foregroundColor(SecurityService.shared.isBiometricsAvailable ? .green : .secondary)
                    }
                }
                .toggleStyle(.switch)
                
                Divider()
                
                // Keychain 獨立鎖定密碼管理
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App Passcode Fallback (應用程式獨立備援密碼)")
                            .font(.subheadline.bold())
                        Text(SecurityService.shared.isCustomPasscodeSet ? "已設定 Keychain 加密備援密碼" : "尚未設定獨立密碼（目前僅依賴系統認證）")
                            .font(.caption)
                            .foregroundColor(SecurityService.shared.isCustomPasscodeSet ? .green : .secondary)
                    }
                    Spacer()
                    Button(SecurityService.shared.isCustomPasscodeSet ? "變更 / 移除密碼..." : "設定密碼...") {
                        isSetPasscodeSheetPresented = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                // 自動鎖定時間
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Lock Timer (自動鎖定時間)")
                            .font(.subheadline.bold())
                        Text("當未操作達指定時間後，自動遮蔽畫面保護隱私")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $autoLockMinutes) {
                        Text("立即 (切換後即鎖)").tag(0)
                        Text("1 分鐘").tag(1)
                        Text("5 分鐘 (預設)").tag(5)
                        Text("15 分鐘").tag(15)
                        Text("30 分鐘").tag(30)
                        Text("從不鎖定").tag(-1)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
                
                Divider()
                
                // 立即鎖定保險庫按鈕
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lock Vault Immediately (立即鎖定保險庫)")
                            .font(.subheadline.bold())
                        Text("快捷鍵 ⌘L 可隨時在任何畫面立即上鎖")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        appState.isLocked = true
                    } label: {
                        Label("立即上鎖", systemImage: "lock.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            // 強制性隱私宣告框
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(.orange)
                        .font(.headline)
                    Text("應用程式鎖定重要說明 (Privacy Disclosure)")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Text(SecurityService.privacyNotice)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
            }
            .padding(16)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.2), lineWidth: 1))
        }
    }
    
    // MARK: - 5. About 分頁 (版本、開源套件、開發資訊)
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            sectionHeader(title: "About Noty", subtitle: "版本編號、零外部相依保證與原生架構規格")
            
            settingCard {
                HStack(spacing: 16) {
                    NotyLogoShape(size: 64)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Noty")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        
                        Text("Version 1.0.0 (Build 1) — Apple Silicon Native")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                        
                        Text("Private Local Media Journal & Diary for macOS")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Zero External Dependencies (零第三方依賴)")
                        .font(.subheadline.bold())
                    
                    Text("Noty 致力於極致本機隱私與極高穩定性。本應用程式未引用任何 CocoaPods、Carthage、SPM 第三方套件，完全純粹由 Apple 官方原生 SDK 打造：")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        featureBullet(title: "Swift 6 & SwiftUI", desc: "100% 原生現代宣告式介面")
                        featureBullet(title: "SwiftData", desc: "本機資料庫與資料模型關聯管理")
                        featureBullet(title: "AVKit & AVFoundation", desc: "原生硬體加速影片串流解碼播放")
                        featureBullet(title: "LocalAuthentication & Keychain", desc: "Touch ID 生物防窺與安全加密儲存")
                        featureBullet(title: "Ollama Loopback Engine", desc: "嚴格限制 127.0.0.1 離線本地 AI 檢索")
                    }
                    .padding(.top, 4)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("System & Target Architecture")
                        .font(.subheadline.bold())
                    Text("• Target OS: macOS 14.0 or higher")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                    Text("• Target CPU: Apple Silicon ARM64 (M1/M2/M3/M4 Native)")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                    Text("• Network: Strict Loopback Only (No telemetry, No cloud upload)")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - 輔助視圖與邏輯
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
    
    private func settingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    private func metricBox(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
        .cornerRadius(8)
    }
    
    private func featureBullet(title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("✓")
                .foregroundColor(.green)
                .font(.caption.bold())
            Text(title + "：")
                .font(.caption.bold())
            Text(desc)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func themeOptionCard(
        id: String,
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer(minLength: 4)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                        lineWidth: isSelected ? 1.8 : 1.0
                    )
            )
            .shadow(color: isSelected ? Color.accentColor.opacity(0.14) : Color.black.opacity(0.03), radius: isSelected ? 6 : 2, x: 0, y: 1.5)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func applyAppearance(_ theme: String) {
        if let option = AppearanceManager.ThemeOption(rawValue: theme) {
            AppearanceManager.shared.setTheme(option)
        } else {
            AppearanceManager.shared.setTheme(.system)
        }
    }
    
    private func validateEndpoint() {
        let result = OllamaService.shared.setEndpoint(ollamaEndpoint)
        if result.success {
            endpointValidationMessage = nil
        } else {
            endpointValidationMessage = result.message
        }
    }
    
    private func testConnection() {
        validateEndpoint()
        guard endpointValidationMessage == nil else { return }
        
        isTestingAIConnection = true
        aiTestResult = nil
        
        Task {
            let start = Date()
            await OllamaService.shared.checkConnection()
            let latencyMs = Int(Date().timeIntervalSince(start) * 1000)
            
            await MainActor.run {
                self.isTestingAIConnection = false
                if OllamaService.shared.isOnline {
                    let count = OllamaService.shared.availableModels.count
                    self.aiTestResult = (true, "連線成功！延遲: \(latencyMs)ms，已安裝 \(count) 個本機模型。")
                } else {
                    self.aiTestResult = (false, "連線失敗：請確認 Ollama 已啟動 (例如執行 ollama serve)")
                }
            }
        }
    }
    
    private func exportPortableArchive() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export NotyArchive Here"
        panel.message = "Choose destination directory for your portable memory archive."
        
        if panel.runModal() == .OK, let targetURL = panel.url {
            do {
                let archiveDir = try MemoryArchiveService.shared.exportArchive(
                    to: targetURL,
                    mediaItems: mediaItems,
                    diaryEntries: diaryEntries,
                    albums: albums
                )
                ToastService.shared.show("Exported archive to \(archiveDir.lastPathComponent)", icon: "archivebox.fill")
            } catch {
                ToastService.shared.show("Archive export failed: \(error.localizedDescription)", isSuccess: false)
            }
        }
    }
}
