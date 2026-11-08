import Foundation
import SwiftData

/// 重複與相似媒體分析服務
public final class DuplicateDetectionService {
    public static let shared = DuplicateDetectionService()
    
    private init() {}
    
    // MARK: - 1. 100% 完全相同比對 (SHA-256)
    public struct ExactDuplicateGroup: Identifiable {
        public let id = UUID()
        public let sha256: String
        public let items: [MediaItem]
        public var totalSize: Int64 {
            items.reduce(0) { $0 + $1.fileSizeBytes }
        }
        public var recoverableSize: Int64 {
            // 保留 1 份後可節省的空間
            guard items.count > 1 else { return 0 }
            return items.dropFirst().reduce(0) { $0 + $1.fileSizeBytes }
        }
    }
    
    /// 找出所有 SHA-256 相同的群組
    public func findExactDuplicates(in items: [MediaItem]) -> [ExactDuplicateGroup] {
        let activeItems = items.filter { !$0.isDeleted && !$0.sha256Hash.isEmpty }
        var groupedByHash: [String: [MediaItem]] = [:]
        
        for item in activeItems {
            groupedByHash[item.sha256Hash, default: []].append(item)
        }
        
        return groupedByHash
            .filter { $0.value.count > 1 }
            .map { ExactDuplicateGroup(sha256: $0.key, items: $0.value) }
            .sorted { $0.recoverableSize > $1.recoverableSize }
    }
    
    // MARK: - 2. 視覺相似照片比對 (Perceptual Hash - dHash)
    public struct SimilarPhotoPair: Identifiable {
        public let id = UUID()
        public let item1: MediaItem
        public let item2: MediaItem
        public let hammingDistance: Int
        public var similarityPercentage: Int {
            let maxDist = 64
            let clampedDist = min(maxDist, max(0, hammingDistance))
            return Int(round(Double(maxDist - clampedDist) / Double(maxDist) * 100))
        }
    }
    
    /// 找出視覺相似度高於門檻的照片對（Hamming 距離 <= maxDistance，預設 8 位元）
    public func findSimilarPhotos(in items: [MediaItem], maxDistance: Int = 8) -> [SimilarPhotoPair] {
        let photoItems = items.filter {
            !$0.isDeleted &&
            $0.mediaType == .image &&
            ($0.perceptualHash?.isEmpty == false)
        }
        
        var pairs: [SimilarPhotoPair] = []
        guard photoItems.count > 1 else { return [] }
        
        for i in 0..<photoItems.count {
            let itemA = photoItems[i]
            guard let hashA = itemA.perceptualHash else { continue }
            
            for j in (i + 1)..<photoItems.count {
                let itemB = photoItems[j]
                // 若 SHA-256 完全相同，則屬於「完全相同」群組，不重複列為「相似」
                if !itemA.sha256Hash.isEmpty && itemA.sha256Hash == itemB.sha256Hash {
                    continue
                }
                guard let hashB = itemB.perceptualHash else { continue }
                
                let dist = MetadataExtractionService.shared.hammingDistance(hash1: hashA, hash2: hashB)
                if dist <= maxDistance {
                    pairs.append(SimilarPhotoPair(item1: itemA, item2: itemB, hammingDistance: dist))
                }
            }
        }
        
        return pairs.sorted { $0.hammingDistance < $1.hammingDistance }
    }
}
