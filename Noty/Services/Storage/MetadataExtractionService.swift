import Foundation
import CoreGraphics
import ImageIO
import AVFoundation
import AppKit

/// 媒體進階元資料解析服務（EXIF、影片軌道與感知雜湊 dHash）
public final class MetadataExtractionService {
    public static let shared = MetadataExtractionService()
    
    private init() {}
    
    // MARK: - 1. EXIF 讀取
    public struct ImageMetadataResult {
        public var width: Int
        public var height: Int
        public var cameraMake: String?
        public var cameraModel: String?
        public var lensModel: String?
        public var iso: Int?
        public var focalLength: Double?
        public var aperture: Double?
        public var exposureTime: String?
        public var capturedDate: Date?
        public var hasGPS: Bool
        public var latitude: Double?
        public var longitude: Double?
        public var perceptualHash: String?
    }
    
    /// 解析圖片之 EXIF、TIFF、GPS 與感知雜湊
    public func extractImageMetadata(from fileURL: URL) -> ImageMetadataResult {
        var result = ImageMetadataResult(
            width: 0,
            height: 0,
            cameraMake: nil,
            cameraModel: nil,
            lensModel: nil,
            iso: nil,
            focalLength: nil,
            aperture: nil,
            exposureTime: nil,
            capturedDate: nil,
            hasGPS: false,
            latitude: nil,
            longitude: nil,
            perceptualHash: nil
        )
        
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            return result
        }
        
        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
            if let w = properties[kCGImagePropertyPixelWidth] as? Int { result.width = w }
            if let h = properties[kCGImagePropertyPixelHeight] as? Int { result.height = h }
            
            // TIFF 字典
            if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                result.cameraMake = tiff[kCGImagePropertyTIFFMake] as? String
                result.cameraModel = tiff[kCGImagePropertyTIFFModel] as? String
                if let dateStr = tiff[kCGImagePropertyTIFFDateTime] as? String {
                    result.capturedDate = parseEXIFDate(dateStr)
                }
            }
            
            // EXIF 字典
            if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
                if let lens = exif[kCGImagePropertyExifLensModel] as? String {
                    result.lensModel = lens
                }
                if let isos = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int], let firstISO = isos.first {
                    result.iso = firstISO
                }
                if let focal = exif[kCGImagePropertyExifFocalLength] as? Double {
                    result.focalLength = focal
                }
                if let fNumber = exif[kCGImagePropertyExifFNumber] as? Double {
                    result.aperture = fNumber
                }
                if let exp = exif[kCGImagePropertyExifExposureTime] as? Double {
                    if exp < 1.0 && exp > 0 {
                        result.exposureTime = "1/\(Int(round(1.0 / exp)))s"
                    } else {
                        result.exposureTime = "\(exp)s"
                    }
                }
                if result.capturedDate == nil, let dateOriginal = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                    result.capturedDate = parseEXIFDate(dateOriginal)
                }
            }
            
            // GPS 字典（嚴格遵從本機隱私原則，不外傳）
            if let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
                if let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
                   let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
                   let lon = gps[kCGImagePropertyGPSLongitude] as? Double,
                   let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String {
                    result.hasGPS = true
                    result.latitude = (latRef == "S") ? -lat : lat
                    result.longitude = (lonRef == "W") ? -lon : lon
                }
            }
        }
        
        // 計算感知雜湊 (dHash)
        result.perceptualHash = computeDifferenceHash(imageSource: imageSource)
        
        return result
    }
    
    // MARK: - 2. 影片元資料解析
    public struct VideoMetadataResult {
        public var durationSeconds: Double
        public var width: Int
        public var height: Int
        public var fps: Double
        public var codec: String
        public var audioTrackCount: Int
        public var capturedDate: Date?
    }
    
    /// 解析影片長度、解析度、幀率、Codec 與音訊軌
    public func extractVideoMetadata(from fileURL: URL) async -> VideoMetadataResult {
        var result = VideoMetadataResult(
            durationSeconds: 0,
            width: 0,
            height: 0,
            fps: 0,
            codec: "Unknown",
            audioTrackCount: 0,
            capturedDate: nil
        )
        
        let asset = AVURLAsset(url: fileURL)
        do {
            let duration = try await asset.load(.duration)
            result.durationSeconds = CMTimeGetSeconds(duration)
            
            // 讀取創作日期
            let metadata = try await asset.load(.commonMetadata)
            for item in metadata {
                if item.commonKey == .commonKeyCreationDate, let dateStr = try? await item.load(.stringValue) {
                    result.capturedDate = parseISO8601Date(dateStr)
                }
            }
            
            // 視訊軌
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            if let videoTrack = videoTracks.first {
                let size = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)
                let transformedSize = size.applying(transform)
                result.width = Int(abs(transformedSize.width))
                result.height = Int(abs(transformedSize.height))
                
                let fps = try await videoTrack.load(.nominalFrameRate)
                result.fps = Double(fps)
                
                let formatDescriptions = try await videoTrack.load(.formatDescriptions)
                if let firstDesc = formatDescriptions.first {
                    let subType = CMFormatDescriptionGetMediaSubType(firstDesc)
                    result.codec = fourCCToString(subType)
                }
            }
            
            // 音訊軌
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            result.audioTrackCount = audioTracks.count
        } catch {
            print("解析影片元資料失敗: \(error.localizedDescription)")
        }
        
        return result
    }
    
    // MARK: - 3. 感知雜湊 (dHash - Difference Hash 64-bit)
    /// 將圖片縮放為 9x8 灰階，計算相鄰像素明度梯度差，產生 64 位元特徵雜湊
    public func computeDifferenceHash(imageSource: CGImageSource) -> String? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 9
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        let width = 9
        let height = 8
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var rawData = [UInt8](repeating: 0, count: width * height)
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var hashValue: UInt64 = 0
        var bitIndex = 0
        
        for y in 0..<height {
            for x in 0..<8 {
                let left = rawData[y * width + x]
                let right = rawData[y * width + (x + 1)]
                if left > right {
                    hashValue |= (1 << (63 - bitIndex))
                }
                bitIndex += 1
            }
        }
        
        return String(format: "%016llx", hashValue)
    }
    
    /// 計算兩組 64 位元 dHash 的 Hamming Distance (位元差異數量)
    /// 距離 0~5 通常代表視覺極度相似或同圖縮放；6~10 代表高度相似構圖
    public func hammingDistance(hash1: String, hash2: String) -> Int {
        guard let val1 = UInt64(hash1, radix: 16),
              let val2 = UInt64(hash2, radix: 16) else {
            return 64
        }
        let xor = val1 ^ val2
        return xor.nonzeroBitCount
    }
    
    // MARK: - 輔助函式
    private func parseEXIFDate(_ dateStr: String) -> Date? {
        // EXIF 標準格式 "yyyy:MM:dd HH:mm:ss"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateStr)
    }
    
    private func parseISO8601Date(_ dateStr: String) -> Date? {
        let iso = ISO8601DateFormatter()
        return iso.date(from: dateStr)
    }
    
    private func fourCCToString(_ code: FourCharCode) -> String {
        let n = Int(code)
        var s = ""
        s.append(Character(UnicodeScalar((n >> 24) & 0xFF)!))
        s.append(Character(UnicodeScalar((n >> 16) & 0xFF)!))
        s.append(Character(UnicodeScalar((n >> 8) & 0xFF)!))
        s.append(Character(UnicodeScalar(n & 0xFF)!))
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "h264" : trimmed
    }
}
