import SwiftUI

/// 導覽列分頁枚舉
public enum NavigationTab: String, CaseIterable, Identifiable {
    case home = "home"
    case gallery = "gallery"
    case diary = "diary"
    case calendar = "calendar"
    case albums = "albums"
    case videos = "videos"
    case favorites = "favorites"
    case recentlyAdded = "recentlyAdded"
    case duplicates = "duplicates"
    case trash = "trash"
    case settings = "settings"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .home: return "Home"
        case .gallery: return "Gallery"
        case .diary: return "Diary"
        case .calendar: return "Calendar"
        case .albums: return "Albums"
        case .videos: return "Videos"
        case .favorites: return "Favorites"
        case .recentlyAdded: return "Recently Added"
        case .duplicates: return "Duplicates"
        case .trash: return "Trash"
        case .settings: return "Settings"
        }
    }
    
    public var iconName: String {
        switch self {
        case .home: return "house"
        case .gallery: return "photo.on.rectangle.angled"
        case .diary: return "book.pages"
        case .calendar: return "calendar"
        case .albums: return "rectangle.stack"
        case .videos: return "film.stack"
        case .favorites: return "heart"
        case .recentlyAdded: return "clock.arrow.circlepath"
        case .duplicates: return "doc.on.doc"
        case .trash: return "trash"
        case .settings: return "gearshape"
        }
    }
    
    public var selectedIconName: String {
        switch self {
        case .home: return "house.fill"
        case .gallery: return "photo.fill.on.rectangle.fill"
        case .diary: return "book.pages.fill"
        case .calendar: return "calendar.circle.fill"
        case .albums: return "rectangle.stack.fill"
        case .videos: return "film.stack.fill"
        case .favorites: return "heart.fill"
        case .recentlyAdded: return "clock.arrow.circlepath"
        case .duplicates: return "doc.on.doc.fill"
        case .trash: return "trash.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

/// 全域應用程式狀態管理
@Observable
public final class AppState {
    /// 當前選中的導覽頁籤
    public var selectedTab: NavigationTab = .gallery
    
    /// 本機隱私保險庫鎖定狀態（對應右下角 Lock 按鈕）
    public var isLocked: Bool = false
    
    /// 是否開啟右側本地 AI 側拉抽屜（對應右側中央 AI← 按鈕）
    public var isAIDrawerOpen: Bool = false
    
    /// 是否開啟上傳與記錄視窗
    public var isUploadSheetPresented: Bool = false
    
    /// 是否開啟日記編寫視窗
    public var isDiaryComposerPresented: Bool = false
    
    /// 當前正在編輯的日記項目（若為 nil 則為新增日記）
    public var diaryToEdit: DiaryEntry? = nil
    
    /// 預先載入的日記草稿文字與範本
    public var preloadedDiaryContent: String? = nil
    public var preloadedDiaryTitle: String? = nil
    
    /// 開啟日記編寫視窗
    public func openDiaryComposer(entry: DiaryEntry? = nil, initialTitle: String? = nil, initialContent: String? = nil) {
        self.diaryToEdit = entry
        self.preloadedDiaryTitle = initialTitle
        self.preloadedDiaryContent = initialContent
        self.isDiaryComposerPresented = true
    }
    
    /// 是否開啟關於 Noty 彈窗
    public var isAboutSheetPresented: Bool = false
    
    /// 是否開啟匯入進度彈窗
    public var isImportProgressModalPresented: Bool = false
    
    /// 是否開啟鍵盤快捷鍵說明視窗
    public var isShortcutsSheetPresented: Bool = false
    
    /// 是否開啟備份與還原管理彈窗
    public var isBackupModalPresented: Bool = false
    
    // MARK: - Phase 9.5 新增彈窗與導航控制
    public var isFolderImportModalPresented: Bool = false
    public var folderToImportURL: URL? = nil
    
    public var isHealthCheckModalPresented: Bool = false
    public var isDuplicateManagerPresented: Bool = false
    public var isAdvancedSearchPresented: Bool = false
    
    public var isCreateAlbumSheetPresented: Bool = false
    public var isAddToAlbumPresented: Bool = false
    public var itemsToAddToAlbum: [MediaItem] = []
    
    // MARK: - Phase 9.875 災難復原、Undo 撤銷與封裝檔管理
    public var isArchiveModalPresented: Bool = false
    public var isDraftRecoveryPromptPresented: Bool = false
    public var lastTrashedMediaItemIDs: [UUID] = []
    public var lastTrashedDiaryEntryIDs: [UUID] = []
    public var undoActionAvailable: Bool = false
    public var undoActionMessage: String = ""
    
    public func recordTrashAction(mediaIDs: [UUID] = [], diaryIDs: [UUID] = [], message: String = "已移入垃圾桶") {
        self.lastTrashedMediaItemIDs = mediaIDs
        self.lastTrashedDiaryEntryIDs = diaryIDs
        self.undoActionAvailable = true
        self.undoActionMessage = message
    }
    
    public func clearUndo() {
        self.lastTrashedMediaItemIDs.removeAll()
        self.lastTrashedDiaryEntryIDs.removeAll()
        self.undoActionAvailable = false
        self.undoActionMessage = ""
    }
    
    /// 排序方式（true: 最舊優先 / false: 最新優先，預設 false）
    public var isAscendingOrder: Bool = false
    
    /// 全域搜尋關鍵字
    public var searchText: String = ""
    
    public init() {}
}
