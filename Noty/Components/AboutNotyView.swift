import SwiftUI

/// 關於 Noty 彈窗
public struct AboutNotyView: View {
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            NotyLogoShape(size: 64)
                .padding(.top, 10)
            
            VStack(spacing: 4) {
                Text(AppConstants.appName)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                
                Text("Version \(AppConstants.appVersion) (Build 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                Label("100% 本機私密，零雲端上傳", systemImage: "shield.lefthalf.filled")
                    .font(.subheadline)
                    .foregroundColor(.green)
                
                Label("Apple Silicon 原生 ARM64 架構", systemImage: "cpu")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Label("本機 Ollama 智慧搜尋驅動", systemImage: "sparkles")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(12)
            
            Text("像 Instagram 一樣記錄生活，但只保存在您自己的 Mac 上。")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 6)
        }
        .padding(24)
        .frame(width: 360)
    }
}
