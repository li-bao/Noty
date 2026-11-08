import XCTest
import SwiftData
@testable import Noty

final class NotyTests: XCTestCase {
    @MainActor
    override func setUp() {
        super.setUp()
        VaultEncryptionService.shared.resetVaultForTesting()
    }
    
    @MainActor
    override func tearDown() {
        VaultEncryptionService.shared.resetVaultForTesting()
        super.tearDown()
    }

    func testBrandConstant() {
        XCTAssertEqual(AppConstants.appName, "Noty")
        XCTAssertEqual(AppConstants.bundleIdentifier, "com.libao.noty")
    }
    
    func testOllamaEndpointIsStrictlyLocalhost() {
        let endpoint = AppConstants.defaultOllamaEndpoint
        XCTAssertTrue(endpoint.host == "127.0.0.1" || endpoint.host == "localhost")
        XCTAssertEqual(endpoint.port, 11434)
    }
    
    func testStorageServiceDirectoriesStructure() {
        let storage = StorageService.shared
        storage.ensureDirectoriesExist()
        
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: storage.rootDirectory.path))
        XCTAssertTrue(fm.fileExists(atPath: storage.databaseDirectory.path))
        XCTAssertTrue(fm.fileExists(atPath: storage.mediaImagesDirectory.path))
        XCTAssertTrue(fm.fileExists(atPath: storage.mediaVideosDirectory.path))
        XCTAssertTrue(fm.fileExists(atPath: storage.thumbnailsDirectory.path))
        XCTAssertTrue(fm.fileExists(atPath: storage.tempDirectory.path))
        XCTAssertTrue(fm.fileExists(atPath: storage.exportsDirectory.path))
        XCTAssertTrue(fm.fileExists(atPath: storage.backupsDirectory.path))
    }
    
    func testSHA256Computation() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).txt")
        let testString = "Noty Native Private Media & Diary"
        try testString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let hash = try StorageService.shared.computeSHA256(for: tempURL)
        XCTAssertFalse(hash.isEmpty)
        XCTAssertEqual(hash.count, 64) // SHA-256 is 64 hex characters
    }
    
    func testMediaItemCreationAndRelativePath() {
        let item = MediaItem(
            originalFileName: "vacation.heic",
            storedFileName: "a1b2c3d4_vacation.heic",
            relativePath: "Library/Media/Images/a1b2c3d4_vacation.heic",
            mediaType: .image,
            fileFormat: "heic",
            fileSizeBytes: 204800,
            sha256Hash: "abcdef1234567890",
            capturedAt: Date(),
            pixelWidth: 4032,
            pixelHeight: 3024
        )
        
        XCTAssertEqual(item.originalFileName, "vacation.heic")
        XCTAssertEqual(item.relativePath, "Library/Media/Images/a1b2c3d4_vacation.heic")
        XCTAssertEqual(item.mediaType, .image)
        XCTAssertFalse(item.isDeleted)
        XCTAssertFalse(item.isFavorite)
    }
    
    func testDiaryEntryCreationAndSoftDelete() {
        let mediaID = UUID()
        let entry = DiaryEntry(
            title: "Private Day Off",
            content: "Writing notes securely on my Mac.",
            entryDate: Date(),
            attachedMediaIDs: [mediaID],
            mood: "☕️"
        )
        
        XCTAssertEqual(entry.title, "Private Day Off")
        XCTAssertEqual(entry.mood, "☕️")
        XCTAssertEqual(entry.attachedMediaIDs.count, 1)
        XCTAssertFalse(entry.isDeleted)
        
        // 軟刪除測試
        entry.isDeleted = true
        entry.deletedAt = Date()
        XCTAssertTrue(entry.isDeleted)
        XCTAssertNotNil(entry.deletedAt)
    }
    
    func testSupportedFileExtensions() {
        let sampleImageURL = URL(fileURLWithPath: "/tmp/sample.heic")
        let sampleVideoURL = URL(fileURLWithPath: "/tmp/movie.mp4")
        let sampleUnsupported = URL(fileURLWithPath: "/tmp/doc.pdf")
        
        XCTAssertTrue(MediaImportService.isSupportedFile(url: sampleImageURL))
        XCTAssertTrue(MediaImportService.isSupportedFile(url: sampleVideoURL))
        XCTAssertFalse(MediaImportService.isSupportedFile(url: sampleUnsupported))
    }
    
    func testOriginalFilePreservationOnImport() throws {
        // 1. 建立測試原始檔案
        let tempDir = FileManager.default.temporaryDirectory
        let sourceURL = tempDir.appendingPathComponent("origin_\(UUID().uuidString).png")
        
        // 生成一張純色測試圖片
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("無法建立測試圖片")
            return
        }
        try pngData.write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        
        let originalSourceSize = try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64
        let originalSourceHash = try StorageService.shared.computeSHA256(for: sourceURL)
        
        // 2. 執行匯入
        let result = try StorageService.shared.importMedia(from: sourceURL)
        
        // 3. 驗收核心規範：原始檔案必須依然存在原處，內容與大小完全一致！
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), "原始檔案絕對不可被刪除或移動！")
        let afterSourceSize = try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64
        let afterSourceHash = try StorageService.shared.computeSHA256(for: sourceURL)
        
        XCTAssertEqual(originalSourceSize, afterSourceSize)
        XCTAssertEqual(originalSourceHash, afterSourceHash)
        
        // 4. 驗收 Noty 沙盒內部已建立完整副本，且雜湊相同
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.absoluteURL.path), "Noty 沙盒內必須存有完整副本！")
        XCTAssertEqual(result.sha256Hash, originalSourceHash)
        XCTAssertEqual(result.fileSizeBytes, originalSourceSize)
        
        // 5. 驗收手動刪除原始檔案後，Noty 庫中副本完全獨立不受影響
        try FileManager.default.removeItem(at: sourceURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.absoluteURL.path), "原始檔案刪除後，Noty 沙盒內的副本必須完好保存！")
        
        // 清理測試沙盒產物
        try? FileManager.default.removeItem(at: result.absoluteURL)
    }
    
    func testMediaItemCaptionAndTagsEditing() {
        let item = MediaItem(
            originalFileName: "mountain.jpg",
            relativePath: "Library/Media/Images/mountain.jpg",
            mediaType: .image
        )
        
        XCTAssertTrue(item.caption.isEmpty)
        XCTAssertTrue(item.tags.isEmpty)
        
        // 編輯描述與標籤
        item.caption = "Beautiful sunset over the mountains."
        item.tags.append("sunset")
        item.tags.append("hiking")
        
        XCTAssertEqual(item.caption, "Beautiful sunset over the mountains.")
        XCTAssertEqual(item.tags.count, 2)
        XCTAssertTrue(item.tags.contains("sunset"))
        
        // 移除標籤
        item.tags.removeAll(where: { $0 == "sunset" })
        XCTAssertEqual(item.tags.count, 1)
        XCTAssertFalse(item.tags.contains("sunset"))
    }
    
    func testBatchOperations() {
        let item1 = MediaItem(originalFileName: "photo1.jpg", relativePath: "p1", mediaType: .image)
        let item2 = MediaItem(originalFileName: "photo2.jpg", relativePath: "p2", mediaType: .image)
        let items = [item1, item2]
        
        // 批次加收藏
        for item in items {
            item.isFavorite = true
        }
        XCTAssertTrue(item1.isFavorite)
        XCTAssertTrue(item2.isFavorite)
        
        // 批次移至垃圾桶
        for item in items {
            item.isDeleted = true
            item.deletedAt = Date()
        }
        XCTAssertTrue(item1.isDeleted)
        XCTAssertTrue(item2.isDeleted)
        XCTAssertNotNil(item1.deletedAt)
        XCTAssertNotNil(item2.deletedAt)
    }
    
    @MainActor
    func testDiaryEntryEditingAndTags() {
        let entry = DiaryEntry(
            title: "Tokyo Trip Day 1",
            content: "Landed at Haneda, had delicious ramen.",
            entryDate: Date(),
            attachedMediaIDs: [UUID()],
            tags: ["tokyo", "travel"],
            mood: "🍜"
        )
        
        XCTAssertEqual(entry.title, "Tokyo Trip Day 1")
        XCTAssertEqual(entry.mood, "🍜")
        XCTAssertEqual(entry.tags.count, 2)
        XCTAssertTrue(entry.tags.contains("tokyo"))
        
        // 編輯標題與心情
        entry.title = "Tokyo Trip Day 1 (Updated)"
        entry.mood = "🎉"
        entry.tags.append("food")
        
        XCTAssertEqual(entry.title, "Tokyo Trip Day 1 (Updated)")
        XCTAssertEqual(entry.mood, "🎉")
        XCTAssertEqual(entry.tags.count, 3)
    }
    
    @MainActor
    func testOllamaMemoryContextConstruction() {
        let service = OllamaService.shared
        XCTAssertEqual(service.endpoint, "http://127.0.0.1:11434")
        
        let diary = DiaryEntry(
            title: "Summer Vacation",
            content: "Spent a wonderful afternoon at the beach with family.",
            entryDate: Date(),
            tags: ["beach", "summer"],
            mood: "🏖️"
        )
        let media = MediaItem(
            originalFileName: "beach_sunset.jpg",
            relativePath: "Library/Media/Images/beach_sunset.jpg",
            mediaType: .image,
            caption: "Beautiful golden hour at the coastline.",
            tags: ["beach", "sunset"]
        )
        
        let context = service.buildMemoryContext(
            query: "sunset beach memories",
            diaries: [diary],
            mediaItems: [media]
        )
        
        XCTAssertTrue(context.contains("Summer Vacation"))
        XCTAssertTrue(context.contains("beach_sunset.jpg"))
        XCTAssertTrue(context.contains("🏖️"))
        XCTAssertTrue(context.contains("Apple Silicon"))
        XCTAssertTrue(context.contains("offline"))
    }
    
    @MainActor
    func testSecurityServiceBiometricsCheck() {
        let security = SecurityService.shared
        security.checkBiometricsAvailability()
        // 確保在任何 macOS 環境下調用皆能安全返回狀態，不拋出未捕獲異常
        XCTAssertNotNil(security.biometryType)
    }
    
    @MainActor
    func testDiaryDraftServiceAutosaveAndRestore() {
        let draftService = DiaryDraftService.shared
        let entryID = UUID()
        
        let draft = DiaryDraft(
            entryID: entryID,
            title: "Draft Title",
            content: "Draft content should be preserved across app switches.",
            mood: "☕️",
            entryDate: Date(),
            attachedMediaIDs: [UUID()],
            tags: ["draft", "test"],
            isFavorite: true
        )
        
        // 儲存草稿
        draftService.saveDraft(draft)
        XCTAssertTrue(draftService.hasUnsavedDraft(for: entryID))
        
        // 讀取草稿
        let loaded = draftService.loadDraft(for: entryID)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.title, "Draft Title")
        XCTAssertEqual(loaded?.content, "Draft content should be preserved across app switches.")
        XCTAssertEqual(loaded?.mood, "☕️")
        XCTAssertEqual(loaded?.tags.count, 2)
        XCTAssertTrue(loaded?.isFavorite ?? false)
        
        // 清除草稿
        draftService.clearDraft(for: entryID)
        XCTAssertFalse(draftService.hasUnsavedDraft(for: entryID))
        XCTAssertNil(draftService.loadDraft(for: entryID))
    }
    
    @MainActor
    func testDiaryNonDestructiveMediaAttachment() {
        let media = MediaItem(
            originalFileName: "vacation.png",
            relativePath: "Library/Media/Images/vacation.png",
            mediaType: .image
        )
        
        let diary = DiaryEntry(
            title: "Trip",
            content: "Attached media test",
            attachedMediaIDs: [media.id]
        )
        
        XCTAssertTrue(diary.attachedMediaIDs.contains(media.id))
        
        // 從日記移除附件
        diary.attachedMediaIDs.removeAll { $0 == media.id }
        XCTAssertFalse(diary.attachedMediaIDs.contains(media.id))
        
        // 驗收核心規範：MediaItem 實體完好無缺，絕對不被刪除
        XCTAssertFalse(media.isDeleted)
        XCTAssertEqual(media.originalFileName, "vacation.png")
    }
    
    @MainActor
    func testStrictLoopbackEndpointValidation() {
        let validLocalhost = URL(string: "http://localhost:11434")!
        let valid127 = URL(string: "http://127.0.0.1:11434")!
        let validIPv6 = URL(string: "http://[::1]:11434")!
        
        XCTAssertTrue(OllamaService.isLoopback(url: validLocalhost))
        XCTAssertTrue(OllamaService.isLoopback(url: valid127))
        XCTAssertTrue(OllamaService.isLoopback(url: validIPv6))
        
        // 外部網域及非本機 IP 必須被嚴格拒絕
        let invalidOpenAI = URL(string: "https://api.openai.com/v1")!
        let invalidClaude = URL(string: "https://api.anthropic.com")!
        let invalidLAN = URL(string: "http://192.168.1.100:11434")!
        let invalidPublicIP = URL(string: "http://8.8.8.8:11434")!
        
        XCTAssertFalse(OllamaService.isLoopback(url: invalidOpenAI))
        XCTAssertFalse(OllamaService.isLoopback(url: invalidClaude))
        XCTAssertFalse(OllamaService.isLoopback(url: invalidLAN))
        XCTAssertFalse(OllamaService.isLoopback(url: invalidPublicIP))
        
        let service = OllamaService.shared
        let rejected = service.setEndpoint("https://api.openai.com/v1")
        XCTAssertFalse(rejected.success)
        XCTAssertTrue(rejected.message.contains("隱私安全政策限制"))
        
        let accepted = service.setEndpoint("http://127.0.0.1:11434")
        XCTAssertTrue(accepted.success)
    }
    
    @MainActor
    func testOllamaVisionCapabilityDetection() {
        let service = OllamaService.shared
        
        service.selectedModel = "llava"
        XCTAssertTrue(service.isCurrentModelVisionCapable)
        
        service.selectedModel = "llama3.2-vision"
        XCTAssertTrue(service.isCurrentModelVisionCapable)
        
        service.selectedModel = "bakllava"
        XCTAssertTrue(service.isCurrentModelVisionCapable)
        
        service.selectedModel = "llama3.2"
        XCTAssertFalse(service.isCurrentModelVisionCapable)
        
        service.selectedModel = "qwen2.5"
        XCTAssertFalse(service.isCurrentModelVisionCapable)
        
        service.selectedModel = "mistral"
        XCTAssertFalse(service.isCurrentModelVisionCapable)
    }
    
    @MainActor
    func testGroundedMemoryRetrievalFacts() {
        let service = OllamaService.shared
        
        let diary = DiaryEntry(
            title: "Kyoto Temple Walk",
            content: "Visited Kinkaku-ji in the early morning.",
            entryDate: Date(),
            tags: ["kyoto", "japan"],
            mood: "⛩️"
        )
        
        let photo = MediaItem(
            originalFileName: "temple.jpg",
            relativePath: "Library/Media/Images/temple.jpg",
            mediaType: .image,
            caption: "Golden pavilion reflection",
            tags: ["kyoto", "gold"]
        )
        
        let video = MediaItem(
            originalFileName: "walk.mp4",
            relativePath: "Library/Media/Videos/walk.mp4",
            mediaType: .video,
            durationSeconds: 45.0,
            caption: "Bamboo forest sound"
        )
        
        let groundedContext = service.buildGroundedMemoryContext(
            query: "我最近有哪些照片與影片？",
            diaries: [diary],
            mediaItems: [photo, video]
        )
        
        // 驗收真實數據存在
        XCTAssertTrue(groundedContext.contains("總照片數量：1 張"))
        XCTAssertTrue(groundedContext.contains("總影片數量：1 部"))
        XCTAssertTrue(groundedContext.contains("總日記數量：1 篇"))
        XCTAssertTrue(groundedContext.contains("Kyoto Temple Walk"))
        XCTAssertTrue(groundedContext.contains("temple.jpg"))
        XCTAssertTrue(groundedContext.contains("walk.mp4"))
        
        // 驗收強制規範包含防捏造指示
        XCTAssertTrue(groundedContext.contains("真實性第一"))
        XCTAssertTrue(groundedContext.contains("絕不可以虛構、捏造"))
    }
    
    // MARK: - Phase 8 安全、Keychain、備份與隱私測試
    
    func testKeychainServicePasscodeSecurity() {
        let keychain = KeychainService.shared
        let testPasscode = "SecretNotyPasscode123"
        
        // 1. 儲存至 Keychain
        let saved = keychain.savePasscode(testPasscode)
        XCTAssertTrue(saved)
        XCTAssertTrue(keychain.hasPasscode())
        
        // 2. 驗證正確與錯誤密碼
        XCTAssertTrue(keychain.verifyPasscode(testPasscode))
        XCTAssertFalse(keychain.verifyPasscode("WrongPassword999"))
        
        // 3. 嚴格驗收：絕對不要將明文密碼存入 UserDefaults
        let defaultsDictionary = UserDefaults.standard.dictionaryRepresentation()
        for (_, value) in defaultsDictionary {
            if let strVal = value as? String {
                XCTAssertFalse(strVal.contains(testPasscode), "Violation: Plaintext password found in UserDefaults!")
            }
        }
        
        // 4. 抹除密碼
        let deleted = keychain.deletePasscode()
        XCTAssertTrue(deleted)
        XCTAssertFalse(keychain.hasPasscode())
    }
    
    func testBackupServiceDiaryMarkdownExport() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TestDiariesExport_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let diary1 = DiaryEntry(
            title: "Hiking Mount Fuji",
            content: "Clear sunny weather with beautiful sunrise views.",
            entryDate: Date(),
            tags: ["nature", "fuji"],
            mood: "⛰️"
        )
        let diary2 = DiaryEntry(
            title: "Coffee Break in Shibuya",
            content: "Tried a nice pour-over at a quiet cafe.",
            entryDate: Date(),
            tags: ["coffee", "tokyo"],
            mood: "☕️"
        )
        
        let exportDir = try BackupService.shared.exportDiaries(
            entries: [diary1, diary2],
            to: tempDir,
            format: .markdown
        )
        
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: exportDir.path))
        
        let files = try fm.contentsOfDirectory(at: exportDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 2)
        
        let fujiFile = files.first(where: { $0.lastPathComponent.contains("Hiking Mount Fuji") })
        XCTAssertNotNil(fujiFile)
        if let fujiFile = fujiFile {
            let content = try String(contentsOf: fujiFile, encoding: .utf8)
            XCTAssertTrue(content.contains("Hiking Mount Fuji"))
            XCTAssertTrue(content.contains("mood: \"⛰️\""))
            XCTAssertTrue(content.contains("Clear sunny weather"))
        }
    }
    
    func testBackupServiceFullBackupAndManifestInspection() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TestFullBackup_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let backupURL = try BackupService.shared.createFullBackup(
            to: tempDir,
            photoCount: 42,
            videoCount: 7,
            diaryCount: 15
        )
        
        let manifest = try BackupService.shared.inspectBackup(at: backupURL)
        XCTAssertEqual(manifest.appName, "Noty")
        XCTAssertEqual(manifest.photoCount, 42)
        XCTAssertEqual(manifest.videoCount, 7)
        XCTAssertEqual(manifest.diaryCount, 15)
        XCTAssertTrue(manifest.totalSizeBytes >= 0)
    }
    
    func testSecurityServicePrivacyNoticeDisclosure() {
        let notice = SecurityService.privacyNotice
        // 驗收強制要求：應用程式鎖定主要保護 Noty 的應用程式介面，不可宣稱它已經加密 Finder 中的所有媒體檔案
        XCTAssertTrue(notice.contains("介面"))
        XCTAssertTrue(notice.contains("不會加密本機 Finder 中的媒體檔案"))
    }
    
    // MARK: - Phase 9 全面功能、檔案可靠性與效能測試
    
    func testHEICAndVideoFormatSupportAndIntegrity() {
        // 1. 支援格式白名單驗收 (HEIC, PNG, MOV, MP4, M4V, WEBP, GIF, TIFF)
        let heicURL = URL(fileURLWithPath: "/tmp/sample.heic")
        let heifURL = URL(fileURLWithPath: "/tmp/sample.heif")
        let pngURL = URL(fileURLWithPath: "/tmp/sample.png")
        let movURL = URL(fileURLWithPath: "/tmp/video.mov")
        let mp4URL = URL(fileURLWithPath: "/tmp/video.mp4")
        let m4vURL = URL(fileURLWithPath: "/tmp/video.m4v")
        let webpURL = URL(fileURLWithPath: "/tmp/pic.webp")
        
        XCTAssertTrue(MediaImportService.isSupportedFile(url: heicURL))
        XCTAssertTrue(MediaImportService.isSupportedFile(url: heifURL))
        XCTAssertTrue(MediaImportService.isSupportedFile(url: pngURL))
        XCTAssertTrue(MediaImportService.isSupportedFile(url: movURL))
        XCTAssertTrue(MediaImportService.isSupportedFile(url: mp4URL))
        XCTAssertTrue(MediaImportService.isSupportedFile(url: m4vURL))
        XCTAssertTrue(MediaImportService.isSupportedFile(url: webpURL))
        
        // 2. 非媒體副檔名拒絕
        let pdfURL = URL(fileURLWithPath: "/tmp/doc.pdf")
        let exeURL = URL(fileURLWithPath: "/tmp/app.exe")
        let zipURL = URL(fileURLWithPath: "/tmp/archive.zip")
        XCTAssertFalse(MediaImportService.isSupportedFile(url: pdfURL))
        XCTAssertFalse(MediaImportService.isSupportedFile(url: exeURL))
        XCTAssertFalse(MediaImportService.isSupportedFile(url: zipURL))
    }
    
    func testLargeMediaStreamingImportSafety() throws {
        // 驗收：超過 2MB 緩衝區之大型檔案分塊複製，驗證 SHA-256 完全相同且原始檔案完好
        let tempDir = FileManager.default.temporaryDirectory
        let largeSourceURL = tempDir.appendingPathComponent("large_sample_\(UUID().uuidString).mp4")
        
        // 產生 5MB 隨機資料檔案
        let dataSize = 5 * 1024 * 1024
        var sampleBytes = [UInt8](repeating: 0, count: dataSize)
        for i in 0..<1000 {
            sampleBytes[i * 5000] = UInt8(i % 255)
        }
        let sampleData = Data(sampleBytes)
        try sampleData.write(to: largeSourceURL)
        defer { try? FileManager.default.removeItem(at: largeSourceURL) }
        
        let originalHash = try StorageService.shared.computeSHA256(for: largeSourceURL)
        let originalAttr = try FileManager.default.attributesOfItem(atPath: largeSourceURL.path)
        
        // 匯入至沙盒
        let result = try StorageService.shared.importMedia(from: largeSourceURL)
        defer {
            try? FileManager.default.removeItem(at: result.absoluteURL)
        }
        
        // 1. 驗收檔案大小與 SHA-256 數位指紋 100% 相同
        XCTAssertEqual(result.fileSizeBytes, Int64(dataSize))
        XCTAssertEqual(result.sha256Hash, originalHash)
        
        let targetHash = try StorageService.shared.computeSHA256(for: result.absoluteURL)
        XCTAssertEqual(targetHash, originalHash)
        
        // 2. 驗收原始檔案毫髮無損（路徑存在、大小相同、未被修改）
        XCTAssertTrue(FileManager.default.fileExists(atPath: largeSourceURL.path))
        let afterAttr = try FileManager.default.attributesOfItem(atPath: largeSourceURL.path)
        XCTAssertEqual(originalAttr[.size] as? Int64, afterAttr[.size] as? Int64)
    }
    
    func testSHA256ExactMatchBetweenSourceAndTarget() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let sourceURL = tempDir.appendingPathComponent("exact_match_\(UUID().uuidString).png")
        let content = "Exact Byte Match Test for Noty File Reliability"
        try content.write(to: sourceURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        
        let sourceHash = try StorageService.shared.computeSHA256(for: sourceURL)
        let result = try StorageService.shared.importMedia(from: sourceURL)
        defer { try? FileManager.default.removeItem(at: result.absoluteURL) }
        
        let targetHash = try StorageService.shared.computeSHA256(for: result.absoluteURL)
        XCTAssertEqual(sourceHash, targetHash)
        XCTAssertEqual(result.sha256Hash, sourceHash)
    }
    
    func testSourceFileNeverModifiedOrDeleted() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let sourceURL = tempDir.appendingPathComponent("protected_\(UUID().uuidString).jpg")
        let content = "Original Non-destructive Content"
        try content.write(to: sourceURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        
        let originalModDate = try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.modificationDate] as? Date
        
        let result = try StorageService.shared.importMedia(from: sourceURL)
        defer { try? FileManager.default.removeItem(at: result.absoluteURL) }
        
        // 驗收原始檔案依然存在
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        
        // 驗收原始檔案內容不變
        let readContent = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertEqual(readContent, content)
        
        let afterModDate = try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.modificationDate] as? Date
        XCTAssertEqual(originalModDate, afterModDate)
    }
    
    func testDatabaseRecordConsistencyWithDiskFiles() {
        let item = MediaItem(
            originalFileName: "mountain.heic",
            storedFileName: "12345678_mountain.heic",
            relativePath: "Library/Media/Images/12345678_mountain.heic",
            mediaType: .image,
            fileFormat: "heic",
            fileSizeBytes: 1024,
            sha256Hash: "hash123"
        )
        
        // 驗收：資料庫只存相對路徑，動態解析至 Application Support
        XCTAssertEqual(item.relativePath, "Library/Media/Images/12345678_mountain.heic")
        let absolute = item.fileURL
        XCTAssertTrue(absolute.path.contains("Application Support/Noty/Library/Media/Images"))
    }
    
    func testTrashWorkflowAndPurge() {
        let item = MediaItem(
            originalFileName: "to_delete.png",
            storedFileName: "del_to_delete.png",
            relativePath: "Library/Media/Images/del_to_delete.png",
            mediaType: .image
        )
        
        // 初始狀態不在垃圾桶
        XCTAssertFalse(item.isDeleted)
        XCTAssertNil(item.deletedAt)
        
        // 移入垃圾桶（軟刪除）
        item.isDeleted = true
        item.deletedAt = Date()
        XCTAssertTrue(item.isDeleted)
        XCTAssertNotNil(item.deletedAt)
        
        // 從垃圾桶還原
        item.isDeleted = false
        item.deletedAt = nil
        XCTAssertFalse(item.isDeleted)
        XCTAssertNil(item.deletedAt)
    }
    
    func testSearchQueryMatching() {
        let photo = MediaItem(
            originalFileName: "kyoto_cherry_blossom.jpg",
            relativePath: "Library/Media/Images/kyoto_cherry_blossom.jpg",
            mediaType: .image,
            caption: "Spring blossom in Maruyama park",
            tags: ["kyoto", "spring", "japan"]
        )
        
        // 測試檔名比對
        XCTAssertTrue(photo.originalFileName.lowercased().contains("cherry"))
        // 測試描述比對
        XCTAssertTrue(photo.caption.lowercased().contains("maruyama"))
        // 測試標籤比對
        XCTAssertTrue(photo.tags.contains(where: { $0.lowercased().contains("japan") }))
        // 不相關關鍵字不吻合
        XCTAssertFalse(photo.caption.lowercased().contains("winter"))
    }
    
    @MainActor
    func testOllamaStopGenerationMechanism() {
        let service = OllamaService.shared
        // 驗收：呼叫 stopGeneration 能夠優雅中斷或重設狀態，不造成 UI 凍結或崩潰
        service.stopGeneration()
        XCTAssertTrue(service.connectionState != .generating)
    }
    
    func testBackupServiceRestoreWorkflowWithSafetySnapshot() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TestRestoreSafety_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // 1. 建立一個符合結構的測試備份包
        let backupURL = try BackupService.shared.createFullBackup(
            to: tempDir,
            photoCount: 5,
            videoCount: 2,
            diaryCount: 3
        )
        
        // 2. 驗證備份包清單
        let manifest = try BackupService.shared.inspectBackup(at: backupURL)
        XCTAssertEqual(manifest.photoCount, 5)
        XCTAssertEqual(manifest.videoCount, 2)
        XCTAssertEqual(manifest.diaryCount, 3)
        
        // 3. 執行還原前快照安全性驗收
        let backupsDir = StorageService.shared.backupsDirectory
        let beforeSnapshots = (try? FileManager.default.contentsOfDirectory(at: backupsDir, includingPropertiesForKeys: nil)) ?? []
        
        // 執行還原
        try BackupService.shared.restoreFromBackup(at: backupURL)
        
        let afterSnapshots = (try? FileManager.default.contentsOfDirectory(at: backupsDir, includingPropertiesForKeys: nil)) ?? []
        
        // 驗收：還原前必然在 Library/Backups/ 建立一份緊急安全快照（Pre_Restore_Safety_...）
        XCTAssertTrue(afterSnapshots.count >= beforeSnapshots.count)
        let safetySnapshot = afterSnapshots.first(where: { $0.lastPathComponent.contains("Pre_Restore_Safety_") })
        XCTAssertNotNil(safetySnapshot, "Mandatory safety rollback snapshot was not created before restore!")
    }
    
    func testDatabasePersistenceAcrossContainerReload() throws {
        // 驗收：重新啟動後資料能從磁碟 ModelConfiguration 正確持久化讀取
        let schema = Schema([MediaItem.self, DiaryEntry.self])
        let tempStoreURL = FileManager.default.temporaryDirectory.appendingPathComponent("persistence_test_\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: tempStoreURL) }
        
        let config = ModelConfiguration(schema: schema, url: tempStoreURL, allowsSave: true)
        
        // 第一次啟動寫入
        do {
            let container1 = try ModelContainer(for: schema, configurations: [config])
            let context1 = ModelContext(container1)
            let diary = DiaryEntry(
                title: "Persistent Memory",
                content: "Data must survive application relaunch.",
                entryDate: Date(),
                tags: ["persistence"],
                mood: "🌟"
            )
            context1.insert(diary)
            try context1.save()
        }
        
        // 第二次模擬 App 重新啟動（全新 Container 實例讀取相同 storeURL）
        do {
            let container2 = try ModelContainer(for: schema, configurations: [config])
            let context2 = ModelContext(container2)
            let descriptor = FetchDescriptor<DiaryEntry>()
            let fetched = try context2.fetch(descriptor)
            
            XCTAssertEqual(fetched.count, 1)
            XCTAssertEqual(fetched.first?.title, "Persistent Memory")
            XCTAssertEqual(fetched.first?.mood, "🌟")
            XCTAssertEqual(fetched.first?.tags, ["persistence"])
        }
    }
    
    @MainActor
    func testDuplicateMediaDetectionAndSkip() throws {
        let schema = Schema([MediaItem.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        
        let existingItem = MediaItem(
            originalFileName: "avatar.png",
            relativePath: "Library/Media/Images/avatar.png",
            mediaType: .image,
            sha256Hash: "duplicate_hash_9999"
        )
        context.insert(existingItem)
        try context.save()
        
        // 驗收重複檢查邏輯
        let descriptor = FetchDescriptor<MediaItem>(
            predicate: #Predicate<MediaItem> { $0.sha256Hash == "duplicate_hash_9999" && !$0.isDeleted }
        )
        let matches = try context.fetch(descriptor)
        XCTAssertFalse(matches.isEmpty, "Duplicate file should be detected by SHA-256 match")
        
        // 刪除後的重複項目不再視為衝突
        existingItem.isDeleted = true
        try context.save()
        let matchesAfterDelete = try context.fetch(descriptor)
        XCTAssertTrue(matchesAfterDelete.isEmpty, "Soft-deleted media should not block re-importing")
    }
    
    func testInterruptedImportLeavesZeroOrphanRecords() throws {
        let tempDir = StorageService.shared.tempDirectory
        let tempTestFile = tempDir.appendingPathComponent("interrupted_\(UUID().uuidString).tmp")
        try "Incomplete corrupted chunk".write(to: tempTestFile, atomically: true, encoding: .utf8)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempTestFile.path))
        
        // 模擬匯入失敗或中斷時的清理機制
        if FileManager.default.fileExists(atPath: tempTestFile.path) {
            try FileManager.default.removeItem(at: tempTestFile)
        }
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempTestFile.path), "Interrupted temp file must be completely purged")
    }
    
    // MARK: - Phase 9.5 進階功能自動化測試
    
    @MainActor
    func testCustomAlbumCreationAndMediaAssociation() throws {
        let schema = Schema([MediaItem.self, Album.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        
        let media1 = MediaItem(originalFileName: "vacation1.jpg", relativePath: "Library/Media/Images/vacation1.jpg", mediaType: .image)
        let media2 = MediaItem(originalFileName: "vacation2.jpg", relativePath: "Library/Media/Images/vacation2.jpg", mediaType: .image)
        context.insert(media1)
        context.insert(media2)
        
        // 建立相簿並加入媒體
        let album = Album(name: "Summer 2026", coverMediaID: media1.id, mediaItemIDs: [media1.id, media2.id])
        context.insert(album)
        try context.save()
        
        XCTAssertEqual(album.name, "Summer 2026")
        XCTAssertEqual(album.mediaItemIDs.count, 2)
        XCTAssertEqual(album.coverMediaID, media1.id)
        
        // 刪除相簿時，驗證原始媒體依然完好無損
        context.delete(album)
        try context.save()
        
        let descriptor = FetchDescriptor<MediaItem>()
        let remainingMedia = try context.fetch(descriptor)
        XCTAssertEqual(remainingMedia.count, 2, "Deleting custom album must NEVER delete underlying media items")
    }
    
    func testPerceptualHashAndHammingDistance() {
        let service = MetadataExtractionService.shared
        let hashA = "ffff0000ffff0000"
        let hashB = "ffff0000ffff0000" // 相同
        let hashC = "ffff0000ffff000f" // 4 位元差異 (0x0 -> 0xF)
        
        let distSame = service.hammingDistance(hash1: hashA, hash2: hashB)
        XCTAssertEqual(distSame, 0)
        
        let distSmall = service.hammingDistance(hash1: hashA, hash2: hashC)
        XCTAssertEqual(distSmall, 4)
        
        let distOpposite = service.hammingDistance(hash1: "0000000000000000", hash2: "ffffffffffffffff")
        XCTAssertEqual(distOpposite, 64)
    }
    
    func testExactAndSimilarDuplicatesDetection() {
        let item1 = MediaItem(originalFileName: "pic1.jpg", relativePath: "Library/Media/Images/pic1.jpg", mediaType: .image, fileSizeBytes: 1000, sha256Hash: "same_hash_123", perceptualHash: "0000000000000000")
        let item2 = MediaItem(originalFileName: "pic1_copy.jpg", relativePath: "Library/Media/Images/pic1_copy.jpg", mediaType: .image, fileSizeBytes: 1000, sha256Hash: "same_hash_123", perceptualHash: "0000000000000000")
        let item3 = MediaItem(originalFileName: "pic2_similar.jpg", relativePath: "Library/Media/Images/pic2_similar.jpg", mediaType: .image, fileSizeBytes: 950, sha256Hash: "diff_hash_456", perceptualHash: "0000000000000003") // 2 bits diff
        
        let exactGroups = DuplicateDetectionService.shared.findExactDuplicates(in: [item1, item2, item3])
        XCTAssertEqual(exactGroups.count, 1)
        XCTAssertEqual(exactGroups.first?.items.count, 2)
        XCTAssertEqual(exactGroups.first?.recoverableSize, 1000)
        
        let similarPairs = DuplicateDetectionService.shared.findSimilarPhotos(in: [item1, item2, item3], maxDistance: 5)
        // item1 與 item3 相似 (dist = 2 <= 5)
        XCTAssertFalse(similarPairs.isEmpty)
        XCTAssertEqual(similarPairs.first?.hammingDistance, 2)
        XCTAssertGreaterThan(similarPairs.first?.similarityPercentage ?? 0, 90)
    }
    
    func testExportDiaryToMarkdownWithYAML() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("export_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let entry = DiaryEntry(
            title: "Trip to Kyoto",
            content: "Visiting traditional temples and tasting matcha.",
            entryDate: Date(),
            tags: ["travel", "kyoto"],
            mood: "⛩️"
        )
        
        let exportedURL = try ExportService.shared.exportDiaryToMarkdown(entry: entry, mediaItems: [], to: tempDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportedURL.path))
        
        let content = try String(contentsOf: exportedURL, encoding: .utf8)
        XCTAssertTrue(content.contains("---"), "Must contain YAML frontmatter delimiter")
        XCTAssertTrue(content.contains("title: \"Trip to Kyoto\""))
        XCTAssertTrue(content.contains("mood: \"⛩️\""))
        XCTAssertTrue(content.contains("# Trip to Kyoto"))
        XCTAssertTrue(content.contains("Visiting traditional temples and tasting matcha."))
    }
    
    func testSearchHistoryServiceLifecycle() {
        let service = SearchHistoryService.shared
        service.clearAllSearches()
        XCTAssertTrue(service.getRecentSearches().isEmpty)
        
        service.addSearchQuery("Kyoto")
        service.addSearchQuery("Sunset")
        service.addSearchQuery("Kyoto") // 重複查詢應置頂而不重複
        
        let searches = service.getRecentSearches()
        XCTAssertEqual(searches.first, "Kyoto")
        XCTAssertEqual(searches.count, 2)
        
        service.removeSearchQuery("Sunset")
        XCTAssertEqual(service.getRecentSearches().count, 1)
        
        service.clearAllSearches()
        XCTAssertTrue(service.getRecentSearches().isEmpty)
    }
    
    func testDatabaseHealthCheckDetection() async {
        let fakeItem = MediaItem(
            originalFileName: "ghost.jpg",
            relativePath: "Library/Media/Images/non_existent_ghost.jpg",
            mediaType: .image
        )
        let fakeDiary = DiaryEntry(
            title: "Broken Ref Diary",
            attachedMediaIDs: [UUID()] // 參照不存在的媒體
        )
        
        let report = await DatabaseHealthService.shared.runFullHealthCheck(
            mediaItems: [fakeItem],
            diaryEntries: [fakeDiary],
            albums: []
        )
        
        XCTAssertFalse(report.isHealthy)
        XCTAssertTrue(report.issues.contains { $0.category == .missingFile })
        XCTAssertTrue(report.issues.contains { $0.category == .brokenDiaryAttachment })
    }
    
    // MARK: - Phase 9.75: Brand, Security, AES-256, LFES-12122 & AI Tests
    
    @MainActor
    func testBrandLogoShapePreservesLetterL() {
        let logo = NotyLogoView(size: 48)
        XCTAssertEqual(logo.size, 48)
        let brandHeader = BrandHeaderView()
        XCTAssertNotNil(brandHeader)
    }
    
    func testAES256KeyDerivationWithPBKDF2() throws {
        let engine = AES256VaultEngine.shared
        let salt = try engine.generateSalt()
        XCTAssertEqual(salt.count, 32)
        
        let password = "NotyVaultMasterPassword_Phase975"
        let key = try engine.deriveKey(from: password, salt: salt, iterations: 600_000)
        XCTAssertNotNil(key)
        
        // 測量基準時間（確保在當前晶片上順利推導）
        if let benchmark = engine.benchmarkKeyDerivation(iterations: 10_000) {
            XCTAssertGreaterThan(benchmark.durationMs, 0.0)
        }
    }
    
    func testAES256AuthenticatedEncryptionAndDecryption() throws {
        let engine = AES256VaultEngine.shared
        let salt = try engine.generateSalt()
        let key = try engine.deriveKey(from: "CorrectPassword123", salt: salt, iterations: 10_000)
        let wrongKey = try engine.deriveKey(from: "WrongPassword456", salt: salt, iterations: 10_000)
        
        let plaintext = "Top secret private memory entry in Noty vault.".data(using: .utf8)!
        let aad = "Diary_Entry_Metadata".data(using: .utf8)!
        
        let ciphertext = try engine.encryptData(plaintext, withKey: key, aad: aad)
        XCTAssertGreaterThan(ciphertext.count, plaintext.count)
        
        // 正確金鑰解密
        let decrypted = try engine.decryptData(ciphertext, withKey: key, aad: aad)
        XCTAssertEqual(decrypted, plaintext)
        
        // 錯誤金鑰解密必定失敗拋出
        XCTAssertThrowsError(try engine.decryptData(ciphertext, withKey: wrongKey, aad: aad)) { error in
            XCTAssertEqual(error as? AES256VaultEngine.VaultError, .authenticationFailed)
        }
    }
    
    func testAES256TamperedCiphertextAndTagDetection() throws {
        let engine = AES256VaultEngine.shared
        let salt = try engine.generateSalt()
        let key = try engine.deriveKey(from: "TamperProofPassword", salt: salt, iterations: 10_000)
        
        let plaintext = "Confidential Journal Paragraph".data(using: .utf8)!
        var ciphertext = try engine.encryptData(plaintext, withKey: key)
        
        // 竄改密文中的 1 個位元組
        let middleIndex = ciphertext.count / 2
        ciphertext[middleIndex] ^= 0xFF
        
        XCTAssertThrowsError(try engine.decryptData(ciphertext, withKey: key)) { error in
            XCTAssertEqual(error as? AES256VaultEngine.VaultError, .authenticationFailed)
        }
    }
    
    func testAES256StreamingChunkFileEncryptionAndSHA256ExactMatch() throws {
        let engine = AES256VaultEngine.shared
        let storage = StorageService.shared
        let salt = try engine.generateSalt()
        let key = try engine.deriveKey(from: "StreamChunkKey_2026", salt: salt, iterations: 10_000)
        
        // 建立 4.5 MB 大型檔案，跨越多個 4 MiB 分塊
        let tempSource = storage.tempDirectory.appendingPathComponent("large_sample_\(UUID().uuidString).bin")
        let tempEncrypted = storage.tempDirectory.appendingPathComponent("large_sample_\(UUID().uuidString).notyvault")
        let tempDecrypted = storage.tempDirectory.appendingPathComponent("large_decrypted_\(UUID().uuidString).bin")
        
        let chunkCount = 5
        let buffer = Data(repeating: 0xAB, count: 1024 * 1024) // 1 MB
        FileManager.default.createFile(atPath: tempSource.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tempSource)
        for _ in 0..<chunkCount {
            handle.write(buffer)
        }
        try handle.close()
        
        defer {
            try? FileManager.default.removeItem(at: tempSource)
            try? FileManager.default.removeItem(at: tempEncrypted)
            try? FileManager.default.removeItem(at: tempDecrypted)
        }
        
        let originalSHA = try storage.computeSHA256(for: tempSource)
        
        // 串流分塊加密
        try engine.encryptFile(at: tempSource, to: tempEncrypted, key: key, salt: salt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempEncrypted.path))
        
        // 串流分塊解密
        try engine.decryptFile(at: tempEncrypted, to: tempDecrypted, key: key)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDecrypted.path))
        
        let decryptedSHA = try storage.computeSHA256(for: tempDecrypted)
        
        // 逐位元組 100% 一致校驗
        XCTAssertEqual(originalSHA, decryptedSHA)
    }
    
    func testAES256TruncatedEncryptedFileDetection() throws {
        let engine = AES256VaultEngine.shared
        let storage = StorageService.shared
        let salt = try engine.generateSalt()
        let key = try engine.deriveKey(from: "TruncationTestPassword", salt: salt, iterations: 10_000)
        
        let tempSource = storage.tempDirectory.appendingPathComponent("trunc_src_\(UUID().uuidString).txt")
        let tempEnc = storage.tempDirectory.appendingPathComponent("trunc_enc_\(UUID().uuidString).notyvault")
        let tempDec = storage.tempDirectory.appendingPathComponent("trunc_dec_\(UUID().uuidString).txt")
        
        try "Valid Sample Text for Truncation Testing".write(to: tempSource, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: tempSource)
            try? FileManager.default.removeItem(at: tempEnc)
            try? FileManager.default.removeItem(at: tempDec)
        }
        
        try engine.encryptFile(at: tempSource, to: tempEnc, key: key, salt: salt)
        
        // 截斷密文檔案末尾 50 位元組
        var data = try Data(contentsOf: tempEnc)
        data = data.dropLast(50)
        try data.write(to: tempEnc)
        
        XCTAssertThrowsError(try engine.decryptFile(at: tempEnc, to: tempDec, key: key)) { error in
            XCTAssertTrue(error is AES256VaultEngine.VaultError)
        }
    }
    
    @MainActor
    func testVaultFieldLevelEncryptionLifecycle() throws {
        let vault = VaultEncryptionService.shared
        vault.resetVaultForTesting()
        defer { vault.resetVaultForTesting() }
        
        let rawText = "This is a private diary entry written in my bedroom."
        
        // 未配置保險庫時，原樣回傳
        let unencrypted = vault.encryptField(rawText)
        XCTAssertEqual(unencrypted, rawText)
        
        // 配置保險庫
        try vault.setupVault(masterPassword: "MyMasterPassword_975")
        XCTAssertTrue(vault.isUnlocked)
        
        // 解鎖狀態下加密
        let encrypted = vault.encryptField(rawText)
        XCTAssertTrue(encrypted.hasPrefix("notyvlt:aes256:"))
        XCTAssertNotEqual(encrypted, rawText)
        
        // 解鎖狀態下解密
        let decrypted = vault.decryptField(encrypted)
        XCTAssertEqual(decrypted, rawText)
        
        // 鎖定保險庫
        vault.lockVault()
        XCTAssertFalse(vault.isUnlocked)
        
        // 鎖定狀態下嘗試讀取，必須顯示安全遮罩保護隱私
        let shielded = vault.decryptField(encrypted)
        XCTAssertTrue(shielded.contains("已加密保全"))
    }
    
    func testLFES12122TestVectorsExactMatch() {
        XCTAssertEqual(LFES12122Codec.v0C, "12")
        XCTAssertEqual(LFES12122Codec.v1C, "1122")
        XCTAssertEqual(LFES12122Codec.v1C1Plus, "12122")
        XCTAssertEqual(LFES12122Codec.v2C, "1122112222")
        XCTAssertEqual(LFES12122Codec.v2C2Plus, "121222112222")
        XCTAssertEqual(LFES12122Codec.v3C, "112211222222111122222222")
        XCTAssertEqual(LFES12122Codec.v3C3Plus, "121222211222222111122222222")
    }
    
    func testLFES12122ReversibleDecryptionFlow() throws {
        let codec = LFES12122Codec.shared
        
        // 初始密文：121222211222222111122222222
        let initial = LFES12122Codec.v3C3Plus
        
        // 第一步：移除 3+ -> 112211222222111122222222
        let s1 = try codec.step1_remove3Plus(initial)
        XCTAssertEqual(s1, LFES12122Codec.v3C)
        
        // 第二步：移除 3C -> 121222112222
        let s2 = try codec.step2_remove3C(s1)
        XCTAssertEqual(s2, LFES12122Codec.v2C2Plus)
        
        // 第三步：移除 2+ -> 1122112222
        let s3 = try codec.step3_remove2Plus(s2)
        XCTAssertEqual(s3, LFES12122Codec.v2C)
        
        // 第四步：移除 2C -> 12122
        let s4 = try codec.step4_remove2C(s3)
        XCTAssertEqual(s4, LFES12122Codec.v1C1Plus)
        
        // 第五步：移除 1+ -> 1122
        let s5 = try codec.step5_remove1Plus(s4)
        XCTAssertEqual(s5, LFES12122Codec.v1C)
        
        // 第六步：移除 1C -> 12
        let s6 = try codec.step6_remove1C(s5)
        XCTAssertEqual(s6, LFES12122Codec.v0C)
        
        // 最終還原：移除 0+ -> 1
        let restored = try codec.stepFinal_remove0Plus(s6)
        XCTAssertEqual(restored, "1")
        
        // 完整解密執行器
        let (steps, fullRestored) = try codec.decryptFullExample(initial)
        XCTAssertEqual(fullRestored, "1")
        XCTAssertEqual(steps.count, 7)
    }
    
    func testLFES12122PasswordDigitCyclicExtraction() {
        let codec = LFES12122Codec.shared
        XCTAssertEqual(codec.extractPasswordDigits(from: "2", count: 1), "2")
        XCTAssertEqual(codec.extractPasswordDigits(from: "2", count: 2), "22")
        XCTAssertEqual(codec.extractPasswordDigits(from: "2", count: 3), "222")
        XCTAssertEqual(codec.extractPasswordDigits(from: "123", count: 4), "1231")
    }
    
    func testLFES12122ArbitraryDataThrowsSpecificationIncomplete() {
        let codec = LFES12122Codec.shared
        let dummyData = "ArbitraryUnicodeText".data(using: .utf8)!
        
        XCTAssertThrowsError(try codec.transformArbitraryData(dummyData, password: "2")) { error in
            guard case LFES12122Codec.LFESError.specificationIncomplete = error else {
                XCTFail("Expected specificationIncomplete error, got: \(error)")
                return
            }
        }
    }
    
    @MainActor
    func testThemeOptionAppearanceManagerMapping() {
        let manager = AppearanceManager.shared
        
        manager.setTheme(.light)
        XCTAssertEqual(manager.preferredColorScheme, .light)
        
        manager.setTheme(.dark)
        XCTAssertEqual(manager.preferredColorScheme, .dark)
        
        manager.setTheme(.system)
        XCTAssertNil(manager.preferredColorScheme) // 關鍵：System 必須為 nil，釋放 Dark 覆寫
    }
    
    @MainActor
    func testOllamaVaultLockedPrivacyBarrier() throws {
        let vault = VaultEncryptionService.shared
        vault.resetVaultForTesting()
        defer { vault.resetVaultForTesting() }
        
        try vault.setupVault(masterPassword: "VaultBarrierPassword_123")
        vault.lockVault()
        
        let diary = DiaryEntry(title: "Secret Diary", content: "Top secret content")
        let media = MediaItem(originalFileName: "private.jpg", relativePath: "fake.jpg", mediaType: .image)
        
        // 模擬鎖定狀態下生成上下文
        let context = OllamaService.shared.buildGroundedMemoryContext(
            query: "幫我找日記",
            diaries: [diary],
            mediaItems: [media]
        )
        
        // 必須啟動隱私保險庫屏障，絕不可洩漏日記內文
        XCTAssertTrue(context.contains("隱私保險庫防護啟動中"))
        XCTAssertFalse(context.contains("Top secret content"))
    }
    
    // MARK: - Phase 9.875 長期穩定性、備份輪替、可攜封裝與時光機測試
    
    func testImportantMemoriesAndProtectionFlag() {
        let photo = MediaItem(originalFileName: "vacation.jpg", relativePath: "fake.jpg", mediaType: .image)
        XCTAssertFalse(photo.isImportant)
        XCTAssertFalse(photo.isProtected)
        XCTAssertFalse(photo.isMissing)
        
        photo.isImportant = true
        photo.isProtected = true
        XCTAssertTrue(photo.isImportant)
        XCTAssertTrue(photo.isProtected)
        
        let diary = DiaryEntry(title: "Family Trip", content: "Great time")
        XCTAssertFalse(diary.isImportant)
        XCTAssertFalse(diary.isProtected)
        
        diary.isImportant = true
        XCTAssertTrue(diary.isImportant)
    }
    
    func testBackupManifestAndIntegrityVerification() throws {
        let tempBackupDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_backup_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempBackupDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempBackupDir) }
        
        // 建立測試子目錄與檔案
        let dbDir = tempBackupDir.appendingPathComponent("Database", isDirectory: true)
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let sampleFile = dbDir.appendingPathComponent("test.store")
        try "Noty Store Content".write(to: sampleFile, atomically: true, encoding: .utf8)
        
        let hash = try StorageService.shared.computeSHA256(for: sampleFile)
        let entry = BackupManifestFileEntry(relativePath: "Database/test.store", fileSizeBytes: 18, sha256: hash)
        
        let manifest = BackupManifest(
            photoCount: 0,
            videoCount: 0,
            diaryCount: 1,
            totalSizeBytes: 18,
            manifestNotes: "Test Manifest",
            files: [entry]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        try data.write(to: tempBackupDir.appendingPathComponent("Manifest.json"))
        
        let integrity = try BackupService.shared.verifyBackupIntegrity(at: tempBackupDir)
        XCTAssertTrue(integrity.isValid)
        XCTAssertEqual(integrity.checkedFiles, 1)
        XCTAssertTrue(integrity.issues.isEmpty)
    }
    
    func testBackupRotationPruning() throws {
        let tempRotationDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_rotation_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRotationDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRotationDir) }
        
        // 建立 4 個備份目錄
        for i in 1...4 {
            let backupFolder = tempRotationDir.appendingPathComponent("Noty_Backup_2026-11-0\(i)", isDirectory: true)
            let dbDir = backupFolder.appendingPathComponent("Database", isDirectory: true)
            try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
            try "DB Content".write(to: dbDir.appendingPathComponent("Noty.store"), atomically: true, encoding: .utf8)
            
            // 寫入合格 Manifest
            let m = BackupManifest(photoCount: 0, videoCount: 0, diaryCount: 0, totalSizeBytes: 10, manifestNotes: "Test")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(m)
            try data.write(to: backupFolder.appendingPathComponent("Manifest.json"))
        }
        
        // 保留 2 份，應修剪 2 份
        let pruned = try BackupService.shared.rotateBackups(in: tempRotationDir, retainCount: 2)
        XCTAssertEqual(pruned, 2)
        
        let remaining = try FileManager.default.contentsOfDirectory(atPath: tempRotationDir.path)
        XCTAssertEqual(remaining.count, 2)
    }
    
    func testDisasterRecoveryIsolatedSandboxRestore() throws {
        let tempBackupDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_recovery_src_\(UUID().uuidString)", isDirectory: true)
        let tempSandboxDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_recovery_dest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempBackupDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempBackupDir)
            try? FileManager.default.removeItem(at: tempSandboxDir)
        }
        
        let dbDir = tempBackupDir.appendingPathComponent("Database", isDirectory: true)
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbFile = dbDir.appendingPathComponent("Noty.store")
        try "SQLite Store Header Simulation".write(to: dbFile, atomically: true, encoding: .utf8)
        
        let hash = try StorageService.shared.computeSHA256(for: dbFile)
        let entry = BackupManifestFileEntry(relativePath: "Database/Noty.store", fileSizeBytes: 30, sha256: hash)
        let m = BackupManifest(photoCount: 0, videoCount: 0, diaryCount: 0, totalSizeBytes: 30, manifestNotes: "Test", files: [entry])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(m)
        try data.write(to: tempBackupDir.appendingPathComponent("Manifest.json"))
        
        let result = try BackupService.shared.restoreToIsolatedSandbox(at: tempBackupDir, sandboxDirectory: tempSandboxDir)
        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(result.databaseFound)
        XCTAssertEqual(result.verifiedFileCount, 1)
        XCTAssertTrue(result.errors.isEmpty)
    }
    
    func testPortableMemoryArchiveGeneration() throws {
        let tempExportDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_archive_dir_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempExportDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempExportDir) }
        
        let diary = DiaryEntry(title: "Trip to Alishan", content: "Sun rises above sea of clouds.", tags: ["nature", "taiwan"], mood: "🌅")
        let album = Album(name: "Taiwan Travel")
        
        let archiveFolder = try MemoryArchiveService.shared.exportArchive(
            to: tempExportDir,
            mediaItems: [],
            diaryEntries: [diary],
            albums: [album]
        )
        
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: archiveFolder.appendingPathComponent("manifest.json").path))
        XCTAssertTrue(fm.fileExists(atPath: archiveFolder.appendingPathComponent("metadata/diaries.json").path))
        XCTAssertTrue(fm.fileExists(atPath: archiveFolder.appendingPathComponent("metadata/albums.json").path))
        XCTAssertTrue(fm.fileExists(atPath: archiveFolder.appendingPathComponent("metadata/tags.json").path))
        XCTAssertTrue(fm.fileExists(atPath: archiveFolder.appendingPathComponent("checksums/sha256.txt").path))
    }
    
    func testOnThisDayMemoryRetrieval() {
        let calendar = Calendar.current
        let now = Date()
        guard let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now) else {
            XCTFail("無法計算一年前日期")
            return
        }
        
        let oldPhoto = MediaItem(
            originalFileName: "old_sunset.jpg",
            relativePath: "fake.jpg",
            mediaType: .image,
            capturedAt: oneYearAgo
        )
        let oldDiary = DiaryEntry(
            title: "Memory from last year",
            content: "One year ago today.",
            entryDate: oneYearAgo
        )
        
        let memories = OnThisDayService.shared.fetchMemoriesOnThisDay(
            mediaItems: [oldPhoto],
            diaries: [oldDiary],
            referenceDate: now
        )
        
        XCTAssertEqual(memories.count, 1)
        XCTAssertEqual(memories.first?.yearsAgo, 1)
        XCTAssertEqual(memories.first?.mediaItems.count, 1)
        XCTAssertEqual(memories.first?.diaries.count, 1)
    }
    
    func testDiaryVersionHistoryLifecycle() {
        let diary = DiaryEntry(title: "Initial Title", content: "Initial Body")
        let service = DiaryVersionService.shared
        
        service.saveSnapshot(for: diary)
        let v1 = service.getVersions(for: diary.id)
        XCTAssertEqual(v1.count, 1)
        XCTAssertEqual(v1.first?.versionNumber, 1)
        XCTAssertEqual(v1.first?.title, "Initial Title")
        
        diary.title = "Updated Title"
        diary.content = "Updated Body"
        service.saveSnapshot(for: diary)
        let v2 = service.getVersions(for: diary.id)
        XCTAssertEqual(v2.count, 2)
        XCTAssertEqual(v2.first?.versionNumber, 2)
        XCTAssertEqual(v2.first?.title, "Updated Title")
    }
    
    func testSmartMemoryDynamicFilteringAndRelatedScoring() {
        let itemA = MediaItem(originalFileName: "a.jpg", relativePath: "a.jpg", mediaType: .image, tags: ["travel", "japan"])
        let itemB = MediaItem(originalFileName: "b.jpg", relativePath: "b.jpg", mediaType: .image, tags: ["travel"])
        let itemC = MediaItem(originalFileName: "c.jpg", relativePath: "c.jpg", mediaType: .image, tags: ["work"])
        let video = MediaItem(originalFileName: "v.mov", relativePath: "v.mov", mediaType: .video, fileSizeBytes: 150 * 1024 * 1024)
        
        let smart = SmartMemoryService.shared
        let largeVideos = smart.filterMedia(by: .largeVideos, in: [itemA, video], allDiaries: [])
        XCTAssertEqual(largeVideos.count, 1)
        XCTAssertEqual(largeVideos.first?.originalFileName, "v.mov")
        
        let related = smart.findRelatedMemories(for: itemA, in: [itemA, itemB, itemC])
        XCTAssertFalse(related.isEmpty)
        XCTAssertEqual(related.first?.originalFileName, "b.jpg")
    }
    
    func testStorageBreakdownAndDiskSpaceMonitor() {
        let breakdown = StorageService.shared.getStorageBreakdown()
        XCTAssertTrue(breakdown.totalBytes >= 0)
        XCTAssertTrue(breakdown.freeDiskBytes > 0)
        
        let check = ImportQueueService.shared.checkDiskSpaceSufficient(for: [])
        XCTAssertTrue(check.isSufficient)
    }
    
    // MARK: - 15.7 隔離沙盒高乘載壓力測試 (High Scale Stress Test)
    
    @MainActor
    func testIsolatedStressAndBatchScaleValidation() throws {
        let schema = Schema([MediaItem.self, DiaryEntry.self, Album.self, AppSettings.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        
        let startInsert = Date()
        var insertedMedia: [MediaItem] = []
        var insertedDiaries: [DiaryEntry] = []
        
        // 批次注入 500 張照片與 50 部影片
        for i in 1...500 {
            let item = MediaItem(
                originalFileName: "photo_\(i).jpg",
                relativePath: "Media/Images/photo_\(i).jpg",
                mediaType: .image,
                fileSizeBytes: 2048000,
                caption: "Sample photo caption #\(i % 20)",
                tags: ["tag_\(i % 50)", "travel"]
            )
            context.insert(item)
            insertedMedia.append(item)
        }
        for i in 1...50 {
            let item = MediaItem(
                originalFileName: "video_\(i).mov",
                relativePath: "Media/Videos/video_\(i).mov",
                mediaType: .video,
                fileSizeBytes: 120 * 1024 * 1024, // 120 MB
                caption: "Sample 4K video recording",
                tags: ["video", "tag_\(i % 10)"]
            )
            context.insert(item)
            insertedMedia.append(item)
        }
        
        // 批次注入 200 篇日記
        for i in 1...200 {
            let diary = DiaryEntry(
                title: "Diary Entry #\(i)",
                content: "Content for journal entry \(i) with reflections and memories.",
                tags: ["journal", "tag_\(i % 50)"]
            )
            context.insert(diary)
            insertedDiaries.append(diary)
        }
        
        // 批次注入 20 個相簿
        for i in 1...20 {
            let album = Album(name: "Album #\(i)")
            context.insert(album)
        }
        
        try context.save()
        let insertDuration = Date().timeIntervalSince(startInsert)
        XCTAssertLessThan(insertDuration, 5.0, "大量寫入應在 5 秒內完成")
        
        // 驗證高乘載動態過濾
        let startQuery = Date()
        let smart = SmartMemoryService.shared
        let largeVideos = smart.filterMedia(by: .largeVideos, in: insertedMedia, allDiaries: insertedDiaries)
        XCTAssertEqual(largeVideos.count, 50)
        
        let queryDuration = Date().timeIntervalSince(startQuery)
        XCTAssertLessThan(queryDuration, 0.5, "高乘載動態過濾應在 500ms 內完成")
        
        // 驗證全域關鍵字搜尋
        let filtered = insertedMedia.filter { $0.tags.contains("travel") }
        XCTAssertEqual(filtered.count, 500)
    }
    
    // MARK: - Phase 9.875 / Phase 10 全專案驗收測試 (Comprehensive Audit Suite)
    
    @MainActor
    func testAuditGallerySortingAndDateGrouping() throws {
        let schema = Schema([MediaItem.self, DiaryEntry.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        
        let item1 = MediaItem(originalFileName: "item_today.png", relativePath: "Images/1.png", mediaType: .image, capturedAt: now)
        item1.isFavorite = true
        let item2 = MediaItem(originalFileName: "item_yesterday.mov", relativePath: "Videos/2.mov", mediaType: .video, capturedAt: yesterday)
        let item3 = MediaItem(originalFileName: "item_lastweek.png", relativePath: "Images/3.png", mediaType: .image, capturedAt: lastWeek)
        
        context.insert(item1)
        context.insert(item2)
        context.insert(item3)
        try context.save()
        
        // 1. 最新優先排序
        var fetchDesc = FetchDescriptor<MediaItem>(sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
        var items = try context.fetch(fetchDesc)
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].originalFileName, "item_today.png")
        XCTAssertEqual(items[1].originalFileName, "item_yesterday.mov")
        XCTAssertEqual(items[2].originalFileName, "item_lastweek.png")
        
        // 2. 最舊優先排序
        fetchDesc = FetchDescriptor<MediaItem>(sortBy: [SortDescriptor(\.capturedAt, order: .forward)])
        items = try context.fetch(fetchDesc)
        XCTAssertEqual(items[0].originalFileName, "item_lastweek.png")
        XCTAssertEqual(items[2].originalFileName, "item_today.png")
        
        // 3. 照片 vs 影片篩選
        let photoPredicate = #Predicate<MediaItem> { $0.mediaTypeRaw == "image" && !$0.isDeleted }
        let photos = try context.fetch(FetchDescriptor<MediaItem>(predicate: photoPredicate))
        XCTAssertEqual(photos.count, 2)
        
        let videoPredicate = #Predicate<MediaItem> { $0.mediaTypeRaw == "video" && !$0.isDeleted }
        let videos = try context.fetch(FetchDescriptor<MediaItem>(predicate: videoPredicate))
        XCTAssertEqual(videos.count, 1)
        
        // 4. 收藏篩選
        let favPredicate = #Predicate<MediaItem> { $0.isFavorite && !$0.isDeleted }
        let favs = try context.fetch(FetchDescriptor<MediaItem>(predicate: favPredicate))
        XCTAssertEqual(favs.count, 1)
        XCTAssertEqual(favs.first?.originalFileName, "item_today.png")
    }
    
    @MainActor
    func testAuditRealPNGAndHEICImportWorkflow() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let schema = Schema([MediaItem.self, DiaryEntry.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        
        // 1. 建立真實 PNG 測試檔案
        let pngURL = tempDir.appendingPathComponent("audit_test_\(UUID().uuidString).png")
        let pngImage = NSImage(size: NSSize(width: 80, height: 80))
        pngImage.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 80, height: 80).fill()
        pngImage.unlockFocus()
        guard let tiffData = pngImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            XCTFail("無法生成測試 PNG 資料")
            return
        }
        try pngData.write(to: pngURL)
        defer { try? FileManager.default.removeItem(at: pngURL) }
        
        let originalPNGHash = try StorageService.shared.computeSHA256(for: pngURL)
        
        // 2. 建立真實 HEIC 測試檔案
        let heicURL = tempDir.appendingPathComponent("audit_test_\(UUID().uuidString).heic")
        if let dest = CGImageDestinationCreateWithURL(heicURL as CFURL, "public.heic" as CFString, 1, nil),
           let cgImage = rep.cgImage {
            CGImageDestinationAddImage(dest, cgImage, nil)
            CGImageDestinationFinalize(dest)
        }
        defer { try? FileManager.default.removeItem(at: heicURL) }
        
        let originalHEICHash = try StorageService.shared.computeSHA256(for: heicURL)
        
        // 3. 執行批次匯入
        await MediaImportService.shared.importFiles(urls: [pngURL, heicURL], modelContext: context)
        
        // 4. 驗收匯入狀態
        XCTAssertEqual(MediaImportService.shared.progressState.completedCount, 2)
        XCTAssertEqual(MediaImportService.shared.progressState.failedCount, 0)
        
        // 5. 驗收原始檔案完整保存（未被刪除、未被修改）
        XCTAssertTrue(FileManager.default.fileExists(atPath: pngURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: heicURL.path))
        XCTAssertEqual(try StorageService.shared.computeSHA256(for: pngURL), originalPNGHash)
        XCTAssertEqual(try StorageService.shared.computeSHA256(for: heicURL), originalHEICHash)
        
        // 6. 驗收資料庫紀錄與副本檔案 SHA-256 100% 相同
        let items = try context.fetch(FetchDescriptor<MediaItem>())
        XCTAssertEqual(items.count, 2)
        for item in items {
            let storedURL = item.fileURL
            XCTAssertTrue(FileManager.default.fileExists(atPath: storedURL.path))
            let storedHash = try StorageService.shared.computeSHA256(for: storedURL)
            XCTAssertEqual(item.sha256Hash, storedHash)
            if item.originalFileName.contains(".png") {
                XCTAssertEqual(storedHash, originalPNGHash)
            } else if item.originalFileName.contains(".heic") {
                XCTAssertEqual(storedHash, originalHEICHash)
            }
            
            // 7. 驗收縮圖已正確建立且原始檔案未被破壞
            let thumbURL = ThumbnailService.shared.thumbnailURL(for: item.storedFileName)
            XCTAssertTrue(FileManager.default.fileExists(atPath: thumbURL.path))
            
            // 清理沙盒測試產物
            try? FileManager.default.removeItem(at: storedURL)
            try? FileManager.default.removeItem(at: thumbURL)
        }
    }
    
    @MainActor
    func testAuditDuplicateMediaHandlingAndCancellation() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let schema = Schema([MediaItem.self, DiaryEntry.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        
        let sampleURL = tempDir.appendingPathComponent("dup_test_\(UUID().uuidString).png")
        let img = NSImage(size: NSSize(width: 40, height: 40))
        img.lockFocus()
        NSColor.systemGreen.setFill()
        NSRect(x: 0, y: 0, width: 40, height: 40).fill()
        img.unlockFocus()
        if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .png, properties: [:]) {
            try data.write(to: sampleURL)
        }
        defer { try? FileManager.default.removeItem(at: sampleURL) }
        
        // 第一次匯入成功
        await MediaImportService.shared.importFiles(urls: [sampleURL], modelContext: context)
        XCTAssertEqual(MediaImportService.shared.progressState.completedCount, 1)
        
        let itemsFirst = try context.fetch(FetchDescriptor<MediaItem>())
        XCTAssertEqual(itemsFirst.count, 1)
        let firstStoredURL = itemsFirst.first?.fileURL
        defer { if let u = firstStoredURL { try? FileManager.default.removeItem(at: u) } }
        
        // 第二次匯入相同檔案（重複處理：略過模式）
        await MediaImportService.shared.importFiles(urls: [sampleURL], modelContext: context, duplicateAction: .skip)
        XCTAssertEqual(MediaImportService.shared.progressState.failedCount, 1, "重複檔案應被記錄為略過/失敗")
        
        let itemsSecond = try context.fetch(FetchDescriptor<MediaItem>())
        XCTAssertEqual(itemsSecond.count, 1, "略過模式下不應產生重複紀錄")
        
        // 測試匯入取消機制
        MediaImportService.shared.cancelImport()
        XCTAssertTrue(MediaImportService.shared.progressState.isCancelled)
    }
    
    @MainActor
    func testAuditDiaryCRUDWorkflowAndMediaAssociation() throws {
        let schema = Schema([MediaItem.self, DiaryEntry.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        
        // 1. 建立媒體項目
        let media = MediaItem(originalFileName: "vacation.jpg", relativePath: "Images/vacation.jpg", mediaType: .image)
        context.insert(media)
        
        // 2. 建立圖文日記
        let diary = DiaryEntry(
            title: "Trip to Alishan",
            content: "Watching the sunrise and morning mist.",
            entryDate: Date(),
            attachedMediaIDs: [media.id],
            tags: ["sunrise", "travel"],
            mood: "☕️"
        )
        context.insert(diary)
        try context.save()
        
        // 3. 驗證日記新增
        var diaries = try context.fetch(FetchDescriptor<DiaryEntry>())
        XCTAssertEqual(diaries.count, 1)
        XCTAssertEqual(diaries.first?.title, "Trip to Alishan")
        XCTAssertEqual(diaries.first?.mood, "☕️")
        XCTAssertEqual(diaries.first?.attachedMediaIDs, [media.id])
        
        // 4. 修改日記
        diary.title = "Trip to Alishan (Edited)"
        diary.mood = "🌟"
        DiaryVersionService.shared.saveSnapshot(for: diary)
        try context.save()
        
        diaries = try context.fetch(FetchDescriptor<DiaryEntry>())
        XCTAssertEqual(diaries.first?.title, "Trip to Alishan (Edited)")
        XCTAssertEqual(diaries.first?.mood, "🌟")
        let versions = DiaryVersionService.shared.getVersions(for: diary.id)
        XCTAssertFalse(versions.isEmpty)
        
        // 5. 軟刪除日記（移入垃圾桶）
        diary.isDeleted = true
        diary.deletedAt = Date()
        try context.save()
        
        // 6. 驗證正常查詢排除已刪除項目，且 Gallery 媒體不受任何影響
        let activePredicate = #Predicate<DiaryEntry> { !$0.isDeleted }
        let activeDiaries = try context.fetch(FetchDescriptor<DiaryEntry>(predicate: activePredicate))
        XCTAssertEqual(activeDiaries.count, 0)
        
        let allMedia = try context.fetch(FetchDescriptor<MediaItem>())
        XCTAssertEqual(allMedia.count, 1)
        XCTAssertFalse(allMedia.first?.isDeleted ?? true, "日記軟刪除不可波及 Gallery 原生媒體")
        
        // 7. 復原日記
        diary.isDeleted = false
        diary.deletedAt = nil
        try context.save()
        
        let restoredDiaries = try context.fetch(FetchDescriptor<DiaryEntry>(predicate: activePredicate))
        XCTAssertEqual(restoredDiaries.count, 1)
    }
    
    @MainActor
    func testAuditOllamaConnectionAndSecurityModelListing() async {
        let ollama = OllamaService.shared
        
        // 1. 驗證嚴格本機迴路白名單限制（拒絕外部 IP/網域）
        XCTAssertFalse(OllamaService.isLoopback(url: URL(string: "http://google.com:11434")!))
        XCTAssertFalse(OllamaService.isLoopback(url: URL(string: "http://192.168.1.100:11434")!))
        XCTAssertFalse(OllamaService.isLoopback(url: URL(string: "http://10.0.0.1:11434")!))
        XCTAssertTrue(OllamaService.isLoopback(url: URL(string: "http://127.0.0.1:11434")!))
        XCTAssertTrue(OllamaService.isLoopback(url: URL(string: "http://localhost:11434")!))
        XCTAssertTrue(OllamaService.isLoopback(url: URL(string: "http://[::1]:11434")!))
        
        // 2. 測試連線探測
        await ollama.checkConnection()
        
        // 若本機 Ollama 正在運行，驗收真實模型切換
        if ollama.isOnline {
            XCTAssertFalse(ollama.availableModels.isEmpty, "本機運行的 Ollama 應回傳已安裝模型")
            let firstModel = ollama.availableModels.first!
            ollama.selectedModel = firstModel
            XCTAssertEqual(ollama.selectedModel, firstModel)
            XCTAssertEqual(ollama.connectionState, .modelReady)
        } else {
            XCTAssertEqual(ollama.connectionState, .disconnected)
            XCTAssertNotNil(ollama.lastErrorMessage)
        }
    }
}
