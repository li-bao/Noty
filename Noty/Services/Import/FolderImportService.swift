import Foundation
import SwiftData

/// 資料夾遞迴掃描與預檢服務
public final class FolderImportService {
    public static let shared = FolderImportService()
    
    private init() {}
    
    public struct FolderScanSummary {
        public var folderURL: URL
        public var totalFilesFound: Int = 0
        public var supportedURLs: [URL] = []
        public var unsupportedURLs: [URL] = []
        public var existingDuplicateURLs: [URL] = []
        public var newImportableURLs: [URL] = []
        public var totalBytes: Int64 = 0
        
        public var formattedTotalSize: String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: totalBytes)
        }
    }
    
    /// 遞迴掃描資料夾並預檢格式與去重狀況
    public func scanFolder(at folderURL: URL, existingHashes: Set<String>) async -> FolderScanSummary {
        var summary = FolderScanSummary(folderURL: folderURL)
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return summary
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  resourceValues.isRegularFile == true else {
                continue
            }
            
            summary.totalFilesFound += 1
            let fileSize = Int64(resourceValues.fileSize ?? 0)
            
            if MediaImportService.isSupportedFile(url: fileURL) {
                summary.supportedURLs.append(fileURL)
                summary.totalBytes += fileSize
                
                // 快速計算 SHA-256 判斷是否已存在於本機庫
                if let hash = try? StorageService.shared.computeSHA256(for: fileURL), existingHashes.contains(hash) {
                    summary.existingDuplicateURLs.append(fileURL)
                } else {
                    summary.newImportableURLs.append(fileURL)
                }
            } else {
                summary.unsupportedURLs.append(fileURL)
            }
        }
        
        return summary
    }
}
