import Foundation
import AppKit
import ImageIO
import AVFoundation

/// 高效縮圖生成與快取服務
/// 獨立存放於 Noty/Library/Thumbnails，絕不修改或覆蓋原始檔案
public final class ThumbnailService: @unchecked Sendable {
    public static let shared = ThumbnailService()
    
    private let memoryCache = NSCache<NSString, NSImage>()
    private let thumbnailsDirectory: URL
    
    private init() {
        self.thumbnailsDirectory = StorageService.shared.thumbnailsDirectory
        memoryCache.countLimit = 300 // 限制記憶體保留最多 300 張縮圖
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100 MB 記憶體上限
    }
    
    /// 取得縮圖儲存目標路徑
    public func thumbnailURL(for storedFileName: String) -> URL {
        let baseName = (storedFileName as NSString).deletingPathExtension
        return thumbnailsDirectory.appendingPathComponent("\(baseName)_thumb.jpg")
    }
    
    /// 檢查磁碟上是否已有快取縮圖
    public func hasThumbnail(for storedFileName: String) -> Bool {
        let thumbURL = thumbnailURL(for: storedFileName)
        return FileManager.default.fileExists(atPath: thumbURL.path)
    }
    
    /// 從記憶體快取或磁碟快取載入縮圖
    public func loadCachedThumbnail(for storedFileName: String) -> NSImage? {
        let key = storedFileName as NSString
        if let image = memoryCache.object(forKey: key) {
            return image
        }
        
        let thumbURL = thumbnailURL(for: storedFileName)
        if let image = NSImage(contentsOf: thumbURL) {
            memoryCache.setObject(image, forKey: key)
            return image
        }
        return nil
    }
    
    /// 非同步生成並儲存縮圖（圖片使用 ImageIO，影片使用 AVAssetImageGenerator）
    @discardableResult
    public func generateThumbnail(
        for mediaURL: URL,
        storedFileName: String,
        isVideo: Bool,
        maxPixelSize: CGFloat = 512
    ) async throws -> URL {
        let targetURL = thumbnailURL(for: storedFileName)
        
        // 若磁碟已有縮圖，直接返回
        if FileManager.default.fileExists(atPath: targetURL.path) {
            return targetURL
        }
        
        var generatedImage: NSImage?
        
        if isVideo {
            generatedImage = try await generateVideoFrame(from: mediaURL, maxPixelSize: maxPixelSize)
        } else {
            generatedImage = generateImageThumbnail(from: mediaURL, maxPixelSize: maxPixelSize)
        }
        
        guard let image = generatedImage,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            throw NSError(domain: "com.libao.noty.thumbnail", code: -1, userInfo: [NSLocalizedDescriptionKey: "縮圖編碼失敗"])
        }
        
        try jpegData.write(to: targetURL, options: .atomic)
        memoryCache.setObject(image, forKey: storedFileName as NSString)
        return targetURL
    }
    
    // MARK: - 圖片縮圖（ImageIO 零記憶體暴增解碼）
    private func generateImageThumbnail(from url: URL, maxPixelSize: CGFloat) -> NSImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        
        guard let cgThumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        return NSImage(cgImage: cgThumbnail, size: NSSize(width: cgThumbnail.width, height: cgThumbnail.height))
    }
    
    // MARK: - 影片代表畫面擷取（AVFoundation）
    private func generateVideoFrame(from url: URL, maxPixelSize: CGFloat) async throws -> NSImage {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        
        // 擷取 0.5 秒位置之畫面，若影片較短則擷取開頭
        let targetTime = CMTime(seconds: 0.5, preferredTimescale: 600)
        
        do {
            let (cgImage, _) = try await generator.image(at: targetTime)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            // 降級嘗試擷取 0 秒
            let (cgImage, _) = try await generator.image(at: .zero)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
    }
    
    // MARK: - 清理暫存縮圖快取
    /// 清空記憶體與磁碟中的縮圖暫存，於需要時會自動重新以原圖/原片生成
    @discardableResult
    public func clearCache() -> Int {
        memoryCache.removeAllObjects()
        let fm = FileManager.default
        var removedCount = 0
        if let files = try? fm.contentsOfDirectory(at: thumbnailsDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fm.removeItem(at: file)
                removedCount += 1
            }
        }
        return removedCount
    }
}
