import SwiftUI
import SwiftData

/// 資料庫健康檢查與維護彈窗
public struct DatabaseHealthModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }) private var allMedia: [MediaItem]
    @Query(filter: #Predicate<DiaryEntry> { !$0.isDeleted }) private var allDiaries: [DiaryEntry]
    @Query private var allAlbums: [Album]
    
    @State private var isChecking = true
    @State private var report: DatabaseHealthService.HealthReport? = nil
    @State private var breakdown: StorageService.StorageBreakdown? = nil
    @State private var actionFeedback: String? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 標題列
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Database Health Check")
                        .font(.title2.bold())
                    Text("Audit physical files, thumbnails, and cross-references to ensure data integrity.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Re-Scan") {
                    runCheck()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
            
            Divider()
            
            if isChecking {
                VStack(spacing: 14) {
                    ProgressView()
                    Text("Running 10-point integrity verification...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let report = report {
                VStack(spacing: 0) {
                    // 摘要橫幅
                    HStack(spacing: 20) {
                        Image(systemName: report.isHealthy ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(report.isHealthy ? .green : .orange)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(report.isHealthy ? "Library is Healthy & Consistent" : "Issues Detected (\(report.issues.count))")
                                .font(.headline)
                            
                            Text("Checked \(report.totalMediaChecked) media items, \(report.totalDiariesChecked) diaries, and \(report.totalAlbumsChecked) albums.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 修復動作工具列
                        HStack(spacing: 8) {
                            Button("Rebuild Thumbnails") {
                                Task {
                                    let count = await DatabaseHealthService.shared.rebuildThumbnails(for: allMedia)
                                    actionFeedback = "Rebuilt \(count) thumbnails."
                                    runCheck()
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button("Clean Temp Files") {
                                let count = DatabaseHealthService.shared.cleanupDanglingTempFiles()
                                actionFeedback = "Cleaned \(count) dangling temp files."
                                runCheck()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(16)
                    .background(report.isHealthy ? Color.green.opacity(0.08) : Color.orange.opacity(0.08))
                    
                    if let feedback = actionFeedback {
                        Text(feedback)
                            .font(.caption.bold())
                            .foregroundColor(.accentColor)
                            .padding(.vertical, 6)
                    }
                    
                    if let bd = breakdown {
                        HStack(spacing: 12) {
                            storageMetric(label: "Library", value: formatBytes(bd.totalBytes), icon: "internaldrive.fill")
                            storageMetric(label: "Photos", value: formatBytes(bd.photosBytes), icon: "photo.fill")
                            storageMetric(label: "Videos", value: formatBytes(bd.videosBytes), icon: "film.fill")
                            storageMetric(label: "Database", value: formatBytes(bd.databaseBytes), icon: "server.rack")
                            storageMetric(label: "Thumbnails", value: formatBytes(bd.thumbnailsBytes), icon: "photo.stack.fill")
                            storageMetric(label: "Backups", value: formatBytes(bd.backupsBytes), icon: "arrow.triangle.2.circlepath")
                            storageMetric(label: "Free Disk", value: formatBytes(bd.freeDiskBytes), icon: "opticaldiscdrive")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.04))
                    }
                    
                    Divider()
                    
                    // 問題清單
                    if report.issues.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "shield.checkerboard")
                                .font(.system(size: 42))
                                .foregroundColor(.green)
                            Text("Zero corruption or missing references found.")
                                .font(.headline)
                            Text("All files correspond perfectly with SwiftData records.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(report.issues) { issue in
                                HStack(spacing: 12) {
                                    Image(systemName: issue.severity == .error ? "xmark.circle.fill" : "exclamationmark.circle.fill")
                                        .foregroundColor(issue.severity == .error ? .red : .orange)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(issue.category.rawValue)
                                                .font(.caption.bold())
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.secondary.opacity(0.12))
                                                .cornerRadius(4)
                                            
                                            Text(issue.description)
                                                .font(.system(size: 13))
                                        }
                                        
                                        if let path = issue.relatedPath {
                                            Text(path)
                                                .font(.caption2.monospaced())
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 740, height: 540)
        .task {
            runCheck()
        }
    }
    
    private func storageMetric(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    private func runCheck() {
        isChecking = true
        Task.detached(priority: .userInitiated) {
            let res = await DatabaseHealthService.shared.runFullHealthCheck(
                mediaItems: allMedia,
                diaryEntries: allDiaries,
                albums: allAlbums
            )
            let bd = StorageService.shared.getStorageBreakdown()
            await MainActor.run {
                self.report = res
                self.breakdown = bd
                self.isChecking = false
            }
        }
    }
}
