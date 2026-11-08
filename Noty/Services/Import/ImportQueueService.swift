import Foundation
import SwiftData

/// 匯入任務狀態枚舉
public enum ImportJobStatus: String, Codable, Sendable {
    case pending = "Pending"
    case copying = "Copying"
    case verifying = "Verifying"
    case generatingThumbnail = "GeneratingThumbnail"
    case committed = "Committed"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

/// 匯入任務持控資料模型
public struct ImportJob: Codable, Identifiable, Sendable {
    public let id: UUID
    public let fileName: String
    public let sourcePath: String
    public let fileSizeBytes: Int64
    public var status: ImportJobStatus
    public var errorMessage: String?
    public let startedAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        fileName: String,
        sourcePath: String,
        fileSizeBytes: Int64 = 0,
        status: ImportJobStatus = .pending,
        errorMessage: String? = nil,
        startedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.sourcePath = sourcePath
        self.fileSizeBytes = fileSizeBytes
        self.status = status
        self.errorMessage = errorMessage
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }
}

/// 持久化匯入佇列與異常崩潰復原服務（ImportQueueService）
/// 負責：
/// - 匯入任務狀態磁碟持久化（import_queue.json）
/// - 啟動時掃描中斷任務與清理孤立暫存
/// - 匯入前磁碟剩餘空間前置預警校驗
public final class ImportQueueService: @unchecked Sendable {
    public static let shared = ImportQueueService()
    
    private let fileManager = FileManager.default
    private let storage = StorageService.shared
    private let queueFileURL: URL
    private let queueLock = NSLock()
    
    private init() {
        self.queueFileURL = storage.tempDirectory.appendingPathComponent("import_queue.json")
    }
    
    // MARK: - 1. 磁碟剩餘空間前置預檢 (Disk Space Pre-check)
    
    public struct DiskSpaceCheckResult: Sendable {
        public let isSufficient: Bool
        public let availableBytes: Int64
        public let requiredBytes: Int64
        public let formattedAvailable: String
        public let formattedRequired: String
    }
    
    /// 檢查磁碟剩餘空間是否足以容納欲匯入之檔案（保留 1.5 倍安全餘裕）
    public func checkDiskSpaceSufficient(for fileURLs: [URL]) -> DiskSpaceCheckResult {
        var totalRequired: Int64 = 0
        for url in fileURLs {
            if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) {
                totalRequired += Int64(size)
            }
        }
        
        let available = storage.getAvailableDiskSpace()
        let safeThreshold = Int64(Double(totalRequired) * 1.5)
        let isSufficient = available > safeThreshold
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        
        return DiskSpaceCheckResult(
            isSufficient: isSufficient,
            availableBytes: available,
            requiredBytes: totalRequired,
            formattedAvailable: formatter.string(fromByteCount: available),
            formattedRequired: formatter.string(fromByteCount: totalRequired)
        )
    }
    
    // MARK: - 2. 佇列狀態讀寫 (Persistence)
    
    public func loadJobs() -> [ImportJob] {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        guard fileManager.fileExists(atPath: queueFileURL.path),
              let data = try? Data(contentsOf: queueFileURL) else {
            return []
        }
        return (try? JSONDecoder().decode([ImportJob].self, from: data)) ?? []
    }
    
    public func saveJobs(_ jobs: [ImportJob]) {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(jobs) {
            try? data.write(to: queueFileURL)
        }
    }
    
    public func updateJobStatus(id: UUID, status: ImportJobStatus, errorMessage: String? = nil) {
        var jobs = loadJobs()
        if let idx = jobs.firstIndex(where: { $0.id == id }) {
            jobs[idx].status = status
            jobs[idx].errorMessage = errorMessage
            jobs[idx].updatedAt = Date()
            saveJobs(jobs)
        }
    }
    
    // MARK: - 3. 程式重啟異常恢復 (Startup Recovery)
    
    public struct RecoveryReport: Sendable {
        public let interruptedJobsCount: Int
        public let cleanedTempFilesCount: Int
        public let reclaimedBytes: Int64
    }
    
    /// 啟動時掃描異常中斷的任務，標記失敗並清理孤立殘留暫存檔
    public func recoverQueueOnLaunch() -> RecoveryReport {
        var jobs = loadJobs()
        var interruptedCount = 0
        
        for i in 0..<jobs.count {
            switch jobs[i].status {
            case .pending, .copying, .verifying, .generatingThumbnail:
                jobs[i].status = .failed
                jobs[i].errorMessage = "程式於匯入作業期間異常中止，已自動回滾暫存。"
                jobs[i].updatedAt = Date()
                interruptedCount += 1
            case .committed, .failed, .cancelled:
                break
            }
        }
        
        saveJobs(jobs)
        let cleanup = storage.cleanOrphanTempFiles()
        
        return RecoveryReport(
            interruptedJobsCount: interruptedCount,
            cleanedTempFilesCount: cleanup.cleanedCount,
            reclaimedBytes: cleanup.reclaimedBytes
        )
    }
}
