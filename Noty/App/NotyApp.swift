import SwiftUI
import SwiftData

@main
struct NotyApp: App {
    @State private var appState = AppState()
    @StateObject private var appearanceManager = AppearanceManager.shared
    
    var sharedModelContainer: ModelContainer = {
        // 確保目錄樹存在 (~/Library/Application Support/Noty/...)
        StorageService.shared.ensureDirectoriesExist()
        
        let schema = Schema([
            MediaItem.self,
            DiaryEntry.self,
            AppSettings.self,
            Album.self
        ])
        
        // 明確指定本機資料庫檔案路徑：Database/Noty.store
        let storeURL = StorageService.shared.databaseFileURL
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("⚠️ 載入主要資料庫失敗，嘗試備份復原策略：\(error.localizedDescription)")
            // 若發生遷移或讀取錯誤，提供優雅降級
            do {
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                fatalError("無法建立 SwiftData ModelContainer: \(error)")
            }
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(appState)
                .modelContainer(sharedModelContainer)
                .preferredColorScheme(appearanceManager.preferredColorScheme)
                .frame(minWidth: 1050, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1120, height: 740)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Noty") {
                    appState.isAboutSheetPresented = true
                }
            }
            
            CommandGroup(after: .appSettings) {
                Button("Lock Noty Vault") {
                    appState.isLocked = true
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
            
            CommandGroup(replacing: .newItem) {
                Button("New Diary Entry...") {
                    appState.openDiaryComposer()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Import Media...") {
                    appState.isUploadSheetPresented = true
                }
                .keyboardShortcut("u", modifiers: .command)
                
                Button("Find in Noty...") {
                    appState.isAdvancedSearchPresented = true
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            
            CommandMenu("View") {
                Button("Home") { appState.selectedTab = .home }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Gallery") { appState.selectedTab = .gallery }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Diary") { appState.selectedTab = .diary }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Calendar") { appState.selectedTab = .calendar }
                    .keyboardShortcut("4", modifiers: .command)
                Button("Albums") { appState.selectedTab = .albums }
                    .keyboardShortcut("5", modifiers: .command)
                
                Divider()
                
                Button("Toggle AI Assistant") {
                    appState.isAIDrawerOpen.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)
            }
            
            CommandGroup(replacing: .help) {
                Button("Noty Keyboard Shortcuts") {
                    appState.isShortcutsSheetPresented = true
                }
                Button("Database Health Check...") {
                    appState.isHealthCheckModalPresented = true
                }
            }
        }
    }
}
