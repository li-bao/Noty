import SwiftUI
import SwiftData

/// 資料夾批次遞迴匯入預檢彈窗
public struct FolderImportModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }) private var allMedia: [MediaItem]
    
    @State private var isScanning = true
    @State private var summary: FolderImportService.FolderScanSummary? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 標題
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Folder Import Pre-Scan")
                        .font(.title2.bold())
                    Text(appState.folderToImportURL?.path ?? "")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
            
            Divider()
            
            if isScanning {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Scanning folder recursively and checking duplicates...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let summary = summary {
                VStack(spacing: 24) {
                    // 統計卡片
                    HStack(spacing: 14) {
                        statPill(title: "Found", value: "\(summary.totalFilesFound)", icon: "doc.on.doc", color: .secondary)
                        statPill(title: "Supported", value: "\(summary.supportedURLs.count)", icon: "photo.stack", color: .blue)
                        statPill(title: "New Items", value: "\(summary.newImportableURLs.count)", icon: "sparkles", color: .green)
                        statPill(title: "Duplicates", value: "\(summary.existingDuplicateURLs.count)", icon: "arrow.triangle.merge", color: .orange)
                        statPill(title: "Total Size", value: summary.formattedTotalSize, icon: "internaldrive", color: .purple)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Pre-Import Overview")
                            .font(.headline)
                        
                        Text("• \(summary.newImportableURLs.count) new memories will be securely copied into Noty Library.\n• \(summary.existingDuplicateURLs.count) files already exist in your library (SHA-256 match).\n• Original files on your disk will never be altered or removed.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    Divider()
                    
                    // 動作按鈕
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .keyboardShortcut(.cancelAction)
                        
                        Spacer()
                        
                        if !summary.existingDuplicateURLs.isEmpty && !summary.newImportableURLs.isEmpty {
                            Button("Import Only New (\(summary.newImportableURLs.count))") {
                                startImport(urls: summary.newImportableURLs)
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Button("Import All Supported (\(summary.supportedURLs.count))") {
                            startImport(urls: summary.supportedURLs)
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(summary.supportedURLs.isEmpty)
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 650, height: 440)
        .task {
            scanFolder()
        }
    }
    
    @ViewBuilder
    private func statPill(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }
    
    private func scanFolder() {
        guard let folderURL = appState.folderToImportURL else {
            dismiss()
            return
        }
        
        isScanning = true
        let existingHashes = Set(allMedia.map { $0.sha256Hash }.filter { !$0.isEmpty })
        
        Task.detached(priority: .userInitiated) {
            let res = await FolderImportService.shared.scanFolder(at: folderURL, existingHashes: existingHashes)
            await MainActor.run {
                self.summary = res
                self.isScanning = false
            }
        }
    }
    
    private func startImport(urls: [URL]) {
        dismiss()
        appState.isImportProgressModalPresented = true
        Task { @MainActor in
            await MediaImportService.shared.importFiles(urls: urls, modelContext: modelContext)
        }
    }
}
