import Foundation
import SwiftData
import CryptoKit
import ImageIO
import AVFoundation
import AppKit

/// 重複衝突動作枚舉
public enum DuplicateHandlingAction: Sendable {
    case skip
    case importAnyway
}

/// 匯入任務狀態報告
public struct ImportProgressState: Sendable {
    public var isImporting: Bool = false
    public var currentFileName: String = ""
    public var totalCount: Int = 0
    public var completedCount: Int = 0
    public var failedCount: Int = 0
    public var currentFileProgress: Double = 0.0 // 0.0 ~ 1.0
    public var overallProgress: Double = 0.0     // 0.0 ~ 1.0
    public var statusDescription: String = ""
    public var isCancelled: Bool = false
    public var errorMessage: String? = nil
}

/// 重複衝突待決事件
public struct DuplicateConflictItem: Identifiable, Sendable {
    public let id = UUID()
    public let fileURL: URL
    public let fileName: String
    public let existingItemTitle: String
    public let sha256: String
}

/// 媒體匯入核心引擎
/// 遵循絕對安全複製流程：讀取 -> 驗證權限 -> 複製至 Temp -> 雙重校驗 (Size & SHA-256) -> 移入 Media -> 建立資料庫紀錄 -> 產生縮圖
@Observable
public final class MediaImportService: @unchecked Sendable {
    public static let shared = MediaImportService()
    
    public var progressState = ImportProgressState()
    public var activeConflict: DuplicateConflictItem? = nil
    
    private var activeTask: Task<Void, Never>? = nil
    private let storage = StorageService.shared
    private let fileManager = FileManager.default
    
    // 支援的副檔名白名單
    public static let supportedImageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "tif", "webp", "bmp", "ico"
    ]
    public static let supportedVideoExtensions: Set<String> = [
        "mov", "mp4", "m4v", "avi", "mkv", "webm"
    ]
    
    public static var allSupportedExtensions: Set<String> {
        supportedImageExtensions.union(supportedVideoExtensions)
    }
    
    private init() {}
    
    /// 檢查某個 URL 是否為支援的媒體格式
    public static func isSupportedFile(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return allSupportedExtensions.contains(ext)
    }
    
    /// 取消當前正在進行的匯入作業
    public func cancelImport() {
        activeTask?.cancel()
        progressState.isCancelled = true
        progressState.statusDescription = "正在取消匯入並清理暫存檔..."
    }
    
    /// 批次匯入檔案清單
    @MainActor
    public func importFiles(
        urls: [URL],
        modelContext: ModelContext,
        duplicateAction: DuplicateHandlingAction = .skip
    ) async {
        guard !urls.isEmpty else { return }
        
        let validURLs = urls.filter { Self.isSupportedFile(url: $0) }
        guard !validURLs.isEmpty else {
            progressState.errorMessage = "所選取的檔案中沒有支援的照片或影片格式。"
            return
        }
        
        // 初始化進度狀態
        progressState = ImportProgressState(
            isImporting: true,
            currentFileName: "",
            totalCount: validURLs.count,
            completedCount: 0,
            failedCount: 0,
            currentFileProgress: 0.0,
            overallProgress: 0.0,
            statusDescription: "準備匯入 \(validURLs.count) 個檔案...",
            isCancelled: false,
            errorMessage: nil
        )
        
        let task = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            for (index, fileURL) in validURLs.enumerated() {
                if Task.isCancelled { break }
                
                await MainActor.run {
                    self.progressState.currentFileName = fileURL.lastPathComponent
                    self.progressState.statusDescription = "正在處理 [\(index + 1)/\(validURLs.count)] \(fileURL.lastPathComponent)..."
                    self.progressState.currentFileProgress = 0.0
                }
                
                let success = await self.processSingleFile(
                    fileURL: fileURL,
                    modelContext: modelContext,
                    duplicateAction: duplicateAction
                )
                
                await MainActor.run {
                    if success {
                        self.progressState.completedCount += 1
                    } else {
                        self.progressState.failedCount += 1
                    }
                    self.progressState.overallProgress = Double(index + 1) / Double(validURLs.count)
                }
            }
            
            await MainActor.run {
                self.progressState.isImporting = false
                if self.progressState.isCancelled {
                    self.progressState.statusDescription = "匯入已取消。已完成: \(self.progressState.completedCount)"
                } else {
                    self.progressState.statusDescription = "匯入完成！成功: \(self.progressState.completedCount)，略過/失敗: \(self.progressState.failedCount)"
                }
            }
        }
        activeTask = task
        await task.value
    }
    
    // MARK: - 單一檔案嚴謹複製流程
    private func processSingleFile(
        fileURL: URL,
        modelContext: ModelContext,
        duplicateAction: DuplicateHandlingAction
    ) async -> Bool {
        // 1. 安全權限存取檢查
        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { fileURL.stopAccessingSecurityScopedResource() }
        }
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("檔案不存在: \(fileURL.path)")
            return false
        }
        
        let ext = fileURL.pathExtension.lowercased()
        let isVideo = Self.supportedVideoExtensions.contains(ext)
        let originalFileName = fileURL.lastPathComponent
        
        // 2. 獲取原始檔案屬性
        guard let sourceAttrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let sourceSize = sourceAttrs[.size] as? Int64 else {
            return false
        }
        
        // 3. 串流計算來源檔案 SHA-256（不佔據過多記憶體）
        guard let sourceHash = try? storage.computeSHA256(for: fileURL) else {
            return false
        }
        
        // 4. 重複檔案檢查
        let isDuplicate = await checkIfDuplicate(hash: sourceHash, modelContext: modelContext)
        if isDuplicate && duplicateAction == .skip {
            print("檔案已存在且設定為略過: \(originalFileName)")
            return false
        }
        
        // 5. 複製至 Library/Temp/
        let tempFileName = "temp_\(UUID().uuidString).\(ext)"
        let tempURL = storage.tempDirectory.appendingPathComponent(tempFileName)
        
        do {
            try copyFileStreaming(from: fileURL, to: tempURL, totalSize: sourceSize)
        } catch {
            print("複製至 Temp 失敗: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tempURL)
            return false
        }
        
        if Task.isCancelled {
            try? fileManager.removeItem(at: tempURL)
            return false
        }
        
        // 6. 驗證暫存檔：檔案大小與 SHA-256
        guard let tempAttrs = try? fileManager.attributesOfItem(atPath: tempURL.path),
              let tempSize = tempAttrs[.size] as? Int64,
              tempSize == sourceSize else {
            print("檔案大小比對失敗！刪除暫存檔。")
            try? fileManager.removeItem(at: tempURL)
            return false
        }
        
        guard let tempHash = try? storage.computeSHA256(for: tempURL),
              tempHash == sourceHash else {
            print("SHA-256 數位指紋不符！可能傳輸損壞，刪除暫存檔。")
            try? fileManager.removeItem(at: tempURL)
            return false
        }
        
        // 7. 驗證無誤，原子性移至正式 Media 資料夾
        let targetDirectory = isVideo ? storage.mediaVideosDirectory : storage.mediaImagesDirectory
        let uniqueID = UUID().uuidString.prefix(8)
        let hashPrefix = String(sourceHash.prefix(8))
        let storedFileName = "\(hashPrefix)_\(uniqueID).\(ext)"
        let finalURL = targetDirectory.appendingPathComponent(storedFileName)
        
        do {
            try fileManager.moveItem(at: tempURL, to: finalURL)
        } catch {
            print("移至正式目錄失敗: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tempURL)
            return false
        }
        
        // 8. 解析元數據（寬高、EXIF、相機、鏡頭、GPS、時長、視訊軌、感知雜湊）
        var pixelWidth = 0
        var pixelHeight = 0
        var durationSeconds: Double = 0.0
        var capturedDate = (sourceAttrs[.creationDate] as? Date) ?? Date()
        var cameraMake: String? = nil
        var cameraModel: String? = nil
        var lensModel: String? = nil
        var iso: Int? = nil
        var focalLength: Double? = nil
        var aperture: Double? = nil
        var exposureTime: String? = nil
        var hasGPS = false
        var latitude: Double? = nil
        var longitude: Double? = nil
        var fps: Double? = nil
        var videoCodec: String? = nil
        var audioTrackCount: Int? = nil
        var perceptualHash: String? = nil
        
        if isVideo {
            let meta = await MetadataExtractionService.shared.extractVideoMetadata(from: finalURL)
            durationSeconds = meta.durationSeconds
            pixelWidth = meta.width
            pixelHeight = meta.height
            fps = meta.fps
            videoCodec = meta.codec
            audioTrackCount = meta.audioTrackCount
            if let d = meta.capturedDate {
                capturedDate = d
            }
        } else {
            let meta = MetadataExtractionService.shared.extractImageMetadata(from: finalURL)
            pixelWidth = meta.width
            pixelHeight = meta.height
            cameraMake = meta.cameraMake
            cameraModel = meta.cameraModel
            lensModel = meta.lensModel
            iso = meta.iso
            focalLength = meta.focalLength
            aperture = meta.aperture
            exposureTime = meta.exposureTime
            hasGPS = meta.hasGPS
            latitude = meta.latitude
            longitude = meta.longitude
            perceptualHash = meta.perceptualHash
            if let d = meta.capturedDate {
                capturedDate = d
            }
        }
        
        // 9. 產生縮圖至 Library/Thumbnails/
        _ = try? await ThumbnailService.shared.generateThumbnail(
            for: finalURL,
            storedFileName: storedFileName,
            isVideo: isVideo
        )
        
        // 10. 寫入 SwiftData
        let relativePath = isVideo ? "Library/Media/Videos/\(storedFileName)" : "Library/Media/Images/\(storedFileName)"
        let finalWidth = pixelWidth
        let finalHeight = pixelHeight
        let finalDuration = durationSeconds
        let finalCaptured = capturedDate
        let finalMake = cameraMake
        let finalModel = cameraModel
        let finalLens = lensModel
        let finalISO = iso
        let finalFocal = focalLength
        let finalAperture = aperture
        let finalExp = exposureTime
        let finalHasGPS = hasGPS
        let finalLat = latitude
        let finalLon = longitude
        let finalFPS = fps
        let finalCodec = videoCodec
        let finalAudio = audioTrackCount
        let finalPHash = perceptualHash
        
        await MainActor.run {
            let item = MediaItem(
                originalFileName: originalFileName,
                storedFileName: storedFileName,
                relativePath: relativePath,
                mediaType: isVideo ? .video : .image,
                fileFormat: ext,
                fileSizeBytes: sourceSize,
                sha256Hash: sourceHash,
                importedAt: Date(),
                capturedAt: finalCaptured,
                pixelWidth: finalWidth,
                pixelHeight: finalHeight,
                durationSeconds: finalDuration,
                cameraMake: finalMake,
                cameraModel: finalModel,
                lensModel: finalLens,
                iso: finalISO,
                focalLength: finalFocal,
                aperture: finalAperture,
                exposureTime: finalExp,
                hasGPS: finalHasGPS,
                latitude: finalLat,
                longitude: finalLon,
                fps: finalFPS,
                videoCodec: finalCodec,
                audioTrackCount: finalAudio,
                perceptualHash: finalPHash
            )
            modelContext.insert(item)
            try? modelContext.save()
        }
        
        return true
    }
    
    // MARK: - 串流檔案複製（大型檔案分塊複製，不暴增記憶體）
    private func copyFileStreaming(from source: URL, to destination: URL, totalSize: Int64) throws {
        guard let inStream = InputStream(url: source),
              let outStream = OutputStream(url: destination, append: false) else {
            throw StorageError.copyFailed("無法開啟輸入或輸出串流")
        }
        
        inStream.open()
        outStream.open()
        defer {
            inStream.close()
            outStream.close()
        }
        
        let bufferSize = 2 * 1024 * 1024 // 2MB 緩衝區
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        var bytesWrittenTotal: Int64 = 0
        
        while inStream.hasBytesAvailable {
            if Task.isCancelled {
                throw StorageError.copyFailed("作業已被使用者取消")
            }
            
            let read = inStream.read(buffer, maxLength: bufferSize)
            if read < 0 {
                throw inStream.streamError ?? StorageError.copyFailed("讀取檔案資料失敗")
            }
            if read == 0 { break } // EOF
            
            var bytesWrittenForChunk = 0
            while bytesWrittenForChunk < read {
                let written = outStream.write(buffer.advanced(by: bytesWrittenForChunk), maxLength: read - bytesWrittenForChunk)
                if written < 0 {
                    throw outStream.streamError ?? StorageError.copyFailed("寫入檔案資料失敗")
                }
                bytesWrittenForChunk += written
            }
            
            bytesWrittenTotal += Int64(read)
            let progress = totalSize > 0 ? Double(bytesWrittenTotal) / Double(totalSize) : 0.0
            
            Task { @MainActor in
                self.progressState.currentFileProgress = progress
            }
        }
    }
    
    @MainActor
    private func checkIfDuplicate(hash: String, modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<MediaItem>(
            predicate: #Predicate<MediaItem> { $0.sha256Hash == hash && !$0.isDeleted }
        )
        let matches = (try? modelContext.fetch(descriptor)) ?? []
        return !matches.isEmpty
    }
}
