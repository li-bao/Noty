import SwiftUI

/// 媒體匯入進度與控制視窗（Import Progress Modal）
public struct ImportProgressModal: View {
    @Environment(\.dismiss) private var dismiss
    private var importService = MediaImportService.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            // 頂部標題與狀態圖示
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 44, height: 44)
                    
                    if importService.progressState.isImporting {
                        ProgressView()
                            .scaleEffect(0.9)
                    } else if importService.progressState.failedCount > 0 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(importService.progressState.isImporting ? "Importing Media..." : "Import Finished")
                        .font(.headline)
                    
                    Text(importService.progressState.statusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                // 當前處理檔案資訊
                if !importService.progressState.currentFileName.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Current File:")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Text(importService.progressState.currentFileName)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        ProgressView(value: importService.progressState.currentFileProgress)
                            .progressViewStyle(.linear)
                    }
                }
                
                // 總進度條
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Overall Progress:")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(importService.progressState.completedCount) of \(importService.progressState.totalCount) files")
                            .font(.caption.bold())
                    }
                    
                    ProgressView(value: importService.progressState.overallProgress)
                        .progressViewStyle(.linear)
                }
                
                // 數據指標摘要（完成數、失敗/略過數）
                HStack(spacing: 12) {
                    metricBadge(
                        title: "Completed",
                        count: importService.progressState.completedCount,
                        color: .green
                    )
                    
                    metricBadge(
                        title: "Skipped / Failed",
                        count: importService.progressState.failedCount,
                        color: importService.progressState.failedCount > 0 ? .orange : .secondary
                    )
                }
                
                if let errorMsg = importService.progressState.errorMessage {
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 20)
            
            Divider()
            
            // 底部操作列
            HStack {
                if importService.progressState.isImporting {
                    Button(role: .cancel) {
                        importService.cancelImport()
                    } label: {
                        Text("Cancel Import")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func metricBadge(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(count)")
                .font(.caption.bold())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }
}
