import SwiftUI

/// Noty 簽名級動態上傳圓弧進度儀表（DynamicUploadArcView）
/// 整合：
/// - 圓弧進度環 (Radial Arc Progress)
/// - 流光動態旋轉光暈 (Liquid Shimmer & Glow)
/// - 實時多檔案上傳佇列計數（如 "12 / 30 Files"、"40%"）
/// - 當前處理檔案名稱即時顯示
public struct DynamicUploadArcView: View {
    public var progress: Double // 0.0 ~ 1.0
    public var completedCount: Int
    public var totalCount: Int
    public var currentFileName: String
    public var isVerifying: Bool
    
    @State private var shimmerAngle: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(
        progress: Double,
        completedCount: Int,
        totalCount: Int,
        currentFileName: String = "",
        isVerifying: Bool = false
    ) {
        self.progress = max(0.0, min(1.0, progress))
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.currentFileName = currentFileName
        self.isVerifying = isVerifying
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // 左側：動態流體圓弧環
            ZStack {
                // 背景軌道
                Circle()
                    .stroke(Color.primary.opacity(0.12), lineWidth: 3.5)
                    .frame(width: 38, height: 38)
                
                // 動態進度圓弧
                Circle()
                    .trim(from: 0.0, to: CGFloat(progress))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor,
                                Color.blue,
                                Color.cyan,
                                Color.accentColor
                            ]),
                            center: .center,
                            startAngle: .degrees(shimmerAngle),
                            endAngle: .degrees(shimmerAngle + 360)
                        ),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 38, height: 38)
                
                // 中央圖示或百分比
                if progress >= 1.0 {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.green)
                } else if isVerifying {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.accentColor)
                } else {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            
            // 右側：詳細上傳資訊與多檔案進度
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(isVerifying ? "Verifying SHA-256..." : "Uploading Memories")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if totalCount > 1 {
                        Text("\(completedCount)/\(totalCount) Files")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                if !currentFileName.isEmpty {
                    Text(currentFileName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 140, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
        .onAppear {
            if !reduceMotion {
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                    shimmerAngle = 360
                }
            }
        }
    }
}
