import SwiftUI

/// 依據 Phase 9.75 最新手繪稿（media_1794052396103_a3951c65.jpg）深度精緻化的 Noty 向量品牌圖形
/// 核心元素包含：
/// 1. 圓角便簽外框
/// 2. 左下角獨立英文字母大寫「L」（原創核心品牌符號，絕非水滴、筆尖或破損線）
/// 3. 頂部與底部水平橫線飾條 (Rule Lines)
/// 4. 中央粗體大寫「N」
/// 5. 「N」兩側雙層水平短劃線飾條（= N =）
public struct NotyLogoShape: View {
    public var size: CGFloat
    public var tintColor: Color?
    
    public init(size: CGFloat = 34, tintColor: Color? = nil) {
        self.size = size
        self.tintColor = tintColor
    }
    
    public var body: some View {
        NotyLogoView(size: size, tintColor: tintColor)
    }
}

/// 左上角永久固定品牌識別區（Brand Header）
/// 遵循不可變更規則：永久保留 Noty 圖標與 Noty 名稱，不能被設定隱藏或取代
public struct BrandHeaderView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 11) {
            NotyLogoView(size: 34)
                .scaleEffect(isHovered && !reduceMotion ? 1.05 : 1.0)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(AppConstants.appName)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .tracking(0.6)
                
                Text("Private Journal")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onHover { hovering in
            if !reduceMotion {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHovered = hovering
                }
            }
        }
    }
}
