import Foundation

/// 日記未儲存草稿資料結構
public struct DiaryDraft: Codable, Equatable {
    public var entryID: UUID?
    public var title: String
    public var content: String
    public var mood: String
    public var entryDate: Date
    public var attachedMediaIDs: [UUID]
    public var tags: [String]
    public var isFavorite: Bool
    public var lastSavedAt: Date
    
    public init(
        entryID: UUID? = nil,
        title: String = "",
        content: String = "",
        mood: String = "😊",
        entryDate: Date = Date(),
        attachedMediaIDs: [UUID] = [],
        tags: [String] = [],
        isFavorite: Bool = false,
        lastSavedAt: Date = Date()
    ) {
        self.entryID = entryID
        self.title = title
        self.content = content
        self.mood = mood
        self.entryDate = entryDate
        self.attachedMediaIDs = attachedMediaIDs
        self.tags = tags
        self.isFavorite = isFavorite
        self.lastSavedAt = lastSavedAt
    }
    
    public var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        attachedMediaIDs.isEmpty &&
        tags.isEmpty
    }
}

/// 日記編輯器自動草稿暫存服務（DiaryDraftService）
/// 確保使用者在編輯文字或切換分頁時，絕不因意外中斷而遺失內容
@MainActor
public final class DiaryDraftService: ObservableObject {
    public static let shared = DiaryDraftService()
    
    private let userDefaultsKeyPrefix = "noty_diary_draft_"
    private let globalNewDraftKey = "noty_diary_draft_new"
    
    @Published public var currentDraft: DiaryDraft? = nil
    @Published public var lastAutoSavedDate: Date? = nil
    
    private init() {}
    
    private func storageKey(for entryID: UUID?) -> String {
        if let id = entryID {
            return "\(userDefaultsKeyPrefix)\(id.uuidString)"
        }
        return globalNewDraftKey
    }
    
    /// 儲存草稿
    public func saveDraft(_ draft: DiaryDraft) {
        guard !draft.isEmpty else {
            clearDraft(for: draft.entryID)
            return
        }
        
        var draftToSave = draft
        draftToSave.lastSavedAt = Date()
        
        let key = storageKey(for: draft.entryID)
        if let data = try? JSONEncoder().encode(draftToSave) {
            UserDefaults.standard.set(data, forKey: key)
            self.lastAutoSavedDate = draftToSave.lastSavedAt
            self.currentDraft = draftToSave
        }
    }
    
    /// 載入草稿
    public func loadDraft(for entryID: UUID?) -> DiaryDraft? {
        let key = storageKey(for: entryID)
        guard let data = UserDefaults.standard.data(forKey: key),
              let draft = try? JSONDecoder().decode(DiaryDraft.self, from: data) else {
            return nil
        }
        return draft
    }
    
    /// 清除草稿（已完成發布或明確捨棄）
    public func clearDraft(for entryID: UUID?) {
        let key = storageKey(for: entryID)
        UserDefaults.standard.removeObject(forKey: key)
        if currentDraft?.entryID == entryID {
            currentDraft = nil
            lastAutoSavedDate = nil
        }
    }
    
    /// 檢查是否有待恢復之草稿
    public func hasUnsavedDraft(for entryID: UUID?) -> Bool {
        loadDraft(for: entryID) != nil
    }
}
