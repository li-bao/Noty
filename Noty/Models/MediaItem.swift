import Foundation
import SwiftData

/// 媒體類型枚舉
public enum MediaType: String, Codable {
    case image
    case video
    case unknown
}

/// 媒體檔案實體（照片、影片與相關元資料）
/// 遵循核心規範：僅儲存相對路徑，大型二進制檔案保存在沙盒磁碟目錄
@Model
public final class MediaItem {
    @Attribute(.unique) public var id: UUID
    public var originalFileName: String
    public var storedFileName: String
    public var relativePath: String
    public var mediaTypeRaw: String
    public var fileFormat: String
    public var fileSizeBytes: Int64
    public var sha256Hash: String
    public var importedAt: Date
    public var capturedAt: Date
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var durationSeconds: Double
    public var caption: String
    public var isFavorite: Bool
    public var tags: [String]
    public var isDeleted: Bool
    public var deletedAt: Date?
    
    // MARK: - Phase 9.5 強化元資料 (EXIF / 影片情報 / 感知雜湊 / 瀏覽紀錄)
    public var cameraMake: String? = nil
    public var cameraModel: String? = nil
    public var lensModel: String? = nil
    public var iso: Int? = nil
    public var focalLength: Double? = nil
    public var aperture: Double? = nil
    public var exposureTime: String? = nil
    public var hasGPS: Bool = false
    public var latitude: Double? = nil
    public var longitude: Double? = nil
    public var fps: Double? = nil
    public var videoCodec: String? = nil
    public var audioTrackCount: Int? = nil
    public var perceptualHash: String? = nil
    public var lastViewedAt: Date? = nil
    public var albumIDs: [UUID] = []
    
    // MARK: - Phase 9.875 長期回憶防護與遺失標記
    public var isImportant: Bool = false
    public var isProtected: Bool = false
    public var isMissing: Bool = false
    
    public var mediaType: MediaType {
        MediaType(rawValue: mediaTypeRaw) ?? .unknown
    }
    
    public var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSizeBytes)
    }
    
    /// 檢查本機實體檔案是否存在
    public var fileExistsOnDisk: Bool {
        StorageService.shared.fileExists(for: relativePath)
    }
    
    /// 本機檔案絕對路徑 URL
    public var fileURL: URL {
        StorageService.shared.absoluteURL(for: relativePath)
    }
    
    public init(
        id: UUID = UUID(),
        originalFileName: String,
        storedFileName: String = "",
        relativePath: String,
        mediaType: MediaType,
        fileFormat: String = "",
        fileSizeBytes: Int64 = 0,
        sha256Hash: String = "",
        importedAt: Date = Date(),
        capturedAt: Date = Date(),
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        durationSeconds: Double = 0.0,
        caption: String = "",
        isFavorite: Bool = false,
        tags: [String] = [],
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        cameraMake: String? = nil,
        cameraModel: String? = nil,
        lensModel: String? = nil,
        iso: Int? = nil,
        focalLength: Double? = nil,
        aperture: Double? = nil,
        exposureTime: String? = nil,
        hasGPS: Bool = false,
        latitude: Double? = nil,
        longitude: Double? = nil,
        fps: Double? = nil,
        videoCodec: String? = nil,
        audioTrackCount: Int? = nil,
        perceptualHash: String? = nil,
        lastViewedAt: Date? = nil,
        albumIDs: [UUID] = [],
        isImportant: Bool = false,
        isProtected: Bool = false,
        isMissing: Bool = false
    ) {
        self.id = id
        self.originalFileName = originalFileName
        self.storedFileName = storedFileName.isEmpty ? originalFileName : storedFileName
        self.relativePath = relativePath
        self.mediaTypeRaw = mediaType.rawValue
        self.fileFormat = fileFormat
        self.fileSizeBytes = fileSizeBytes
        self.sha256Hash = sha256Hash
        self.importedAt = importedAt
        self.capturedAt = capturedAt
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.durationSeconds = durationSeconds
        self.caption = caption
        self.isFavorite = isFavorite
        self.tags = tags
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.cameraMake = cameraMake
        self.cameraModel = cameraModel
        self.lensModel = lensModel
        self.iso = iso
        self.focalLength = focalLength
        self.aperture = aperture
        self.exposureTime = exposureTime
        self.hasGPS = hasGPS
        self.latitude = latitude
        self.longitude = longitude
        self.fps = fps
        self.videoCodec = videoCodec
        self.audioTrackCount = audioTrackCount
        self.perceptualHash = perceptualHash
        self.lastViewedAt = lastViewedAt
        self.albumIDs = albumIDs
        self.isImportant = isImportant
        self.isProtected = isProtected
        self.isMissing = isMissing
    }
}
