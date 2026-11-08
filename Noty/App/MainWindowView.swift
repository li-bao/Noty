import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Noty 桌面應用程式主視窗
/// 整合左側 Sidebar、中央 Main Content、右側 Utility Rail、AI 側拉面板、進度彈窗與拖曳匯入
public struct MainWindowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var isDraggingOver = false
    @State private var lockErrorMessage: String? = nil
    @State private var isAuthenticating: Bool = false
    @State private var passcodeText: String = ""
    @State private var shakeOffset: CGFloat = 0
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // 三大主要區域佈局：A. 左側 Sidebar | B. 中央 Main Content | C. 右側 Utility Rail
            HStack(spacing: 0) {
                // A. 左側 Sidebar (寬度 210~240 pt)
                SidebarNavigationView()
                    .frame(width: 220)
                
                Divider()
                    .opacity(0.6)
                
                // B. 中央 Main Content (主要工作區)
                mainContentSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider()
                    .opacity(0.6)
                
                // C. 右側 Utility Rail (寬度 72 pt)
                UtilityRailView()
            }
            
            // 拖曳放置提示浮層（Liquid Glass 全視窗展開提示層）
            DynamicFullWindowDropZone(isDragging: isDraggingOver) { _ in }
            
            // 右上角動態上傳圓弧進度指示器（Dynamic Upload Arc）
            if MediaImportService.shared.progressState.isImporting {
                VStack {
                    HStack {
                        Spacer()
                        DynamicUploadArcView(
                            progress: MediaImportService.shared.progressState.overallProgress,
                            completedCount: MediaImportService.shared.progressState.completedCount,
                            totalCount: MediaImportService.shared.progressState.totalCount,
                            currentFileName: MediaImportService.shared.progressState.currentFileName,
                            isVerifying: MediaImportService.shared.progressState.statusDescription.contains("校驗") || MediaImportService.shared.progressState.statusDescription.contains("SHA")
                        )
                        .padding(.top, 14)
                        .padding(.trailing, 84)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
            }
            
            // 右側滑入式本機 Ollama AI 面板 (以浮層形式滑入，不壓縮中央內容)
            if appState.isAIDrawerOpen {
                HStack(spacing: 0) {
                    Spacer()
                    AIAssistantPanelView()
                        .transition(.move(edge: .trailing))
                }
            }
            
            // 輕量操作反饋通知浮層 (Toast)
            if let toast = ToastService.shared.currentToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        if let icon = toast.icon {
                            Image(systemName: icon)
                                .foregroundColor(toast.isSuccess ? .green : .red)
                        }
                        Text(toast.message)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(24)
                    .overlay(
                        Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toast)
            }
            
            // 本機私密保險庫鎖定遮罩 (Lock Overlay)
            if appState.isLocked {
                lockOverlayView
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 1050, minHeight: 680)
        .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.8), value: appState.isAIDrawerOpen)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: appState.isLocked)
        .sheet(isPresented: Bindable(appState).isUploadSheetPresented) {
            UploadModalView()
        }
        .sheet(isPresented: Bindable(appState).isAboutSheetPresented) {
            AboutNotyView()
        }
        .sheet(isPresented: Bindable(appState).isImportProgressModalPresented) {
            ImportProgressModal()
        }
        .sheet(isPresented: Bindable(appState).isDiaryComposerPresented) {
            DiaryComposerSheet(entry: appState.diaryToEdit)
        }
        .sheet(isPresented: Bindable(appState).isShortcutsSheetPresented) {
            KeyboardShortcutsSheet()
        }
        .sheet(isPresented: Bindable(appState).isBackupModalPresented) {
            BackupManagerModal()
        }
        .sheet(isPresented: Bindable(appState).isFolderImportModalPresented) {
            FolderImportModal()
        }
        .sheet(isPresented: Bindable(appState).isHealthCheckModalPresented) {
            DatabaseHealthModal()
        }
        .sheet(isPresented: Bindable(appState).isDuplicateManagerPresented) {
            DuplicateManagerModal()
        }
        .sheet(isPresented: Bindable(appState).isAdvancedSearchPresented) {
            AdvancedSearchView()
        }
        .sheet(isPresented: Bindable(appState).isAddToAlbumPresented) {
            AddToAlbumSheet()
        }
        .onAppear {
            let tabString = UserDefaults.standard.string(forKey: "startup_tab") ?? "gallery"
            if let tab = NavigationTab(rawValue: tabString) {
                appState.selectedTab = tab
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .notyRequestAutoLock)) { _ in
            if !appState.isLocked {
                withAnimation(.easeInOut(duration: 0.22)) {
                    appState.isLocked = true
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            handleDroppedFiles(providers: providers)
        }
        .background {
            // macOS 全域鍵盤快捷鍵
            Group {
                Button("") { appState.isUploadSheetPresented = true }
                    .keyboardShortcut("u", modifiers: .command)
                Button("") { appState.openDiaryComposer() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("") { appState.isLocked = true }
                    .keyboardShortcut("l", modifiers: .command)
                Button("") { appState.isLocked = true }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("") { appState.isAdvancedSearchPresented = true }
                    .keyboardShortcut("f", modifiers: .command)
                Button("") {
                    if !reduceMotion {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            appState.isAIDrawerOpen.toggle()
                        }
                    } else {
                        appState.isAIDrawerOpen.toggle()
                    }
                }
                .keyboardShortcut("k", modifiers: .command)
                Button("") { appState.selectedTab = .gallery }
                    .keyboardShortcut("2", modifiers: .command)
                Button("") { appState.selectedTab = .diary }
                    .keyboardShortcut("3", modifiers: .command)
                Button("") { appState.selectedTab = .calendar }
                    .keyboardShortcut("4", modifiers: .command)
                Button("") { appState.selectedTab = .albums }
                    .keyboardShortcut("5", modifiers: .command)
                Button("") { appState.selectedTab = .settings }
                    .keyboardShortcut(",", modifiers: .command)
            }
            .opacity(0)
            .allowsHitTesting(false)
        }
    }
    
    // MARK: - 中央主要內容區切換
    @ViewBuilder
    private var mainContentSection: some View {
        Group {
            switch appState.selectedTab {
            case .home:
                HomeView()
            case .gallery:
                GalleryView()
            case .diary:
                DiaryView()
            case .calendar:
                CalendarView()
            case .albums:
                AlbumsView()
            case .videos:
                VideosView()
            case .favorites:
                FavoritesView()
            case .recentlyAdded:
                RecentlyAddedView()
            case .duplicates:
                DuplicateManagerModal()
            case .trash:
                TrashView()
            case .settings:
                SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }
    
    // MARK: - 處理拖曳匯入
    private func handleDroppedFiles(providers: [NSItemProvider]) -> Bool {
        var droppedURLs: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    droppedURLs.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            guard !droppedURLs.isEmpty else { return }
            
            // 若拖曳的是資料夾，觸發資料夾預檢彈窗
            if let firstURL = droppedURLs.first, (try? firstURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                appState.folderToImportURL = firstURL
                appState.isFolderImportModalPresented = true
                return
            }
            
            appState.isImportProgressModalPresented = true
            Task { @MainActor in
                await MediaImportService.shared.importFiles(
                    urls: droppedURLs,
                    modelContext: modelContext
                )
            }
        }
        
        return true
    }
    
    // MARK: - 保險庫上鎖遮罩
    private var lockOverlayView: some View {
        ZStack {
            VisualEffectBlurView(material: .fullScreenUI, blendingMode: .withinWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                NotyLogoShape(size: 64)
                    .padding(.bottom, 4)
                
                VStack(spacing: 6) {
                    Text("Noty is Locked")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    
                    Text("Your private memories and diaries are secured on this Mac.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let err = lockErrorMessage {
                    Text(err)
                        .font(.caption.bold())
                        .foregroundColor(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(6)
                        .transition(.opacity)
                }
                
                // 生物辨識 Touch ID 解鎖按鈕
                Button(action: handleUnlock) {
                    HStack(spacing: 8) {
                        Image(systemName: "touchid")
                            .font(.system(size: 16))
                        Text(isAuthenticating ? "Verifying..." : "Unlock with Touch ID")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isAuthenticating)
                .padding(.top, 4)
                
                // 獨立備援密碼解鎖欄位（若已在 Keychain 設定）
                if SecurityService.shared.isCustomPasscodeSet {
                    HStack(spacing: 8) {
                        SecureField("或輸入備援解鎖密碼...", text: $passcodeText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                            .onSubmit {
                                handlePasscodeUnlock()
                            }
                        
                        Button("解鎖") {
                            handlePasscodeUnlock()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                        .buttonStyle(.plain)
                        .disabled(passcodeText.isEmpty)
                    }
                    .padding(.top, 4)
                }
                
                // 隱私權益宣告橫幅（強制性安全邊界提示）
                VStack(spacing: 4) {
                    Text("⚠️ 注意：應用程式鎖定主要保護 Noty 的應用程式介面防窺，")
                    Text("不會加密本機 Finder 中的原始媒體檔案。")
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            }
            .offset(x: shakeOffset)
            .padding(42)
            .liquidGlass(cornerRadius: 24)
        }
        .onAppear {
            SecurityService.shared.refreshCustomPasscodeStatus()
            handleUnlock()
        }
    }
    
    private func handleUnlock() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        lockErrorMessage = nil
        
        Task { @MainActor in
            let success = await SecurityService.shared.requestUnlockVault()
            isAuthenticating = false
            if success {
                unlockSuccess()
            } else {
                lockErrorMessage = SecurityService.shared.authErrorMessage ?? "生物識別解鎖失敗"
            }
        }
    }
    
    private func handlePasscodeUnlock() {
        let success = SecurityService.shared.unlockWithCustomPasscode(passcodeText)
        if success {
            unlockSuccess()
        } else {
            lockErrorMessage = "密碼不正確，請重新輸入"
            triggerShakeAnimation()
        }
    }
    
    private func unlockSuccess() {
        passcodeText = ""
        lockErrorMessage = nil
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 0.22)) {
                appState.isLocked = false
            }
        } else {
            appState.isLocked = false
        }
    }
    
    private func triggerShakeAnimation() {
        withAnimation(.easeInOut(duration: 0.08)) {
            shakeOffset = 12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.08)) {
                self.shakeOffset = -12
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.easeInOut(duration: 0.08)) {
                self.shakeOffset = 6
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.easeInOut(duration: 0.08)) {
                self.shakeOffset = 0
            }
        }
    }
}

/// macOS 毛玻璃特效橋接組件
public struct VisualEffectBlurView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    
    public init(material: NSVisualEffectView.Material, blendingMode: NSVisualEffectView.BlendingMode) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
