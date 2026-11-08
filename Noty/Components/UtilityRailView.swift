import SwiftUI
import AppKit
import SwiftData
import UniformTypeIdentifiers

/// 右側輔助工具軌道（Utility Rail）
/// 整合 Apple Liquid Glass 膠囊化元件：
/// - 右上角：Quick Upload 流體膠囊按鈕
/// - 右側中央：本機 Ollama AI 智慧抽屜拉柄
/// - 右下角：[... 🔒] More 與 Lock 組合膠囊控制盒
public struct UtilityRailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @AppStorage("enable_ai_assistant") private var enableAIAssistant = true
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 右上角：Quick Upload 按鈕（Liquid Glass 圓弧膠囊造型）
            VStack(spacing: 0) {
                Button(action: {
                    openNativeFilePickerAndImport()
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.accentColor)
                        
                        Text("quick\nupload")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(-1)
                    }
                    .frame(width: 58, height: 54)
                    .liquidCapsule(isInteractive: true)
                }
                .buttonStyle(.plain)
                .help("快速選擇相片或影片匯入至 Noty (⌘U)")
                .accessibilityLabel("Quick Upload")
                .accessibilityHint("Select photos or videos to import into Noty library")
            }
            .padding(.top, 14)
            
            Spacer()
            
            // MARK: - 右側中央：固定本機 AI 助理觸發拉柄（受 AI 設定開關控制，忠實呼應手繪稿 [AI ←] 按鈕）
            if enableAIAssistant {
                Button(action: {
                    if !reduceMotion {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            appState.isAIDrawerOpen.toggle()
                        }
                    } else {
                        appState.isAIDrawerOpen.toggle()
                    }
                }) {
                    VStack(spacing: 3) {
                        Text("AI")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(appState.isAIDrawerOpen ? .white : .primary)
                        
                        Image(systemName: appState.isAIDrawerOpen ? "arrow.right" : "arrow.left")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(appState.isAIDrawerOpen ? .white : .accentColor)
                    }
                    .frame(width: 52, height: 56)
                    .liquidCapsule(isActive: appState.isAIDrawerOpen, isInteractive: true)
                }
                .buttonStyle(.plain)
                .help("開啟/收起本機 Ollama AI 搜尋與回憶助理 (⌘K)")
                .accessibilityLabel("Local AI Assistant")
                .accessibilityHint(appState.isAIDrawerOpen ? "Close AI drawer" : "Open AI drawer")
            }
            
            Spacer()
            
            // MARK: - 右下角：[... 🔒] More 與 Lock 組合控制盒（忠實呼應手繪稿右下角 [... 🔒] 標記）
            HStack(spacing: 2) {
                // More 選單按鈕（包含使用者規範指定之 7 大核心項目）
                Menu {
                    Button {
                        appState.selectedTab = .settings
                    } label: {
                        Label("Settings...", systemImage: "gearshape")
                    }
                    
                    Button {
                        openDatabaseFolderInFinder()
                    } label: {
                        Label("Open Library Folder", systemImage: "folder")
                    }
                    
                    Divider()
                    
                    Button {
                        appState.isBackupModalPresented = true
                    } label: {
                        Label("Export Backup...", systemImage: "arrow.down.doc")
                    }
                    
                    Button {
                        appState.isBackupModalPresented = true
                    } label: {
                        Label("Import Backup...", systemImage: "arrow.up.doc")
                    }
                    
                    Divider()
                    
                    Button {
                        appState.isHealthCheckModalPresented = true
                    } label: {
                        Label("Database Health Check...", systemImage: "stethoscope")
                    }
                    
                    Button {
                        appState.isDuplicateManagerPresented = true
                    } label: {
                        Label("Scan for Duplicates...", systemImage: "doc.on.doc")
                    }
                    
                    Divider()
                    
                    Button {
                        appState.isShortcutsSheetPresented = true
                    } label: {
                        Label("Keyboard Shortcuts", systemImage: "command.square")
                    }
                    
                    Button {
                        appState.isAboutSheetPresented = true
                    } label: {
                        Label("About Noty", systemImage: "info.circle")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        NSApp.terminate(nil)
                    } label: {
                        Label("Quit Noty", systemImage: "power")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 26, height: 32)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 26, height: 32)
                .help("更多功能與設定")
                .accessibilityLabel("More Options")
                .accessibilityHint("Open preferences, backups, and shortcuts menu")
                
                Divider()
                    .frame(height: 14)
                    .opacity(0.5)
                
                // Lock 隱私保險庫按鈕
                Button(action: {
                    if !reduceMotion {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            appState.isLocked = true
                        }
                    } else {
                        appState.isLocked = true
                    }
                }) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 26, height: 32)
                }
                .buttonStyle(.plain)
                .help("立即鎖定 Noty 保護隱私 (⌘L)")
                .accessibilityLabel("Lock Vault")
                .accessibilityHint("Immediately lock Noty private vault interface")
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .liquidCapsule(isInteractive: false)
            .padding(.bottom, 14)
        }
        .frame(width: 72)
        .background(Color.clear)
    }
    
    // MARK: - 原生動作
    
    private func openNativeFilePickerAndImport() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Photos or Videos to Import to Noty"
        openPanel.prompt = "Import"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        
        let allowedUTTypes: [UTType] = [
            .image,
            .movie,
            .video,
            UTType("public.heic") ?? .image,
            UTType("public.heif") ?? .image,
            UTType("org.webmproject.webp") ?? .image
        ]
        openPanel.allowedContentTypes = allowedUTTypes
        
        openPanel.begin { response in
            guard response == .OK, !openPanel.urls.isEmpty else { return }
            
            let selectedURLs = openPanel.urls
            appState.isImportProgressModalPresented = true
            
            Task { @MainActor in
                await MediaImportService.shared.importFiles(
                    urls: selectedURLs,
                    modelContext: modelContext
                )
            }
        }
    }
    
    private func openDatabaseFolderInFinder() {
        let appSupportURL = StorageService.shared.rootDirectory
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: appSupportURL.path)
    }
}
