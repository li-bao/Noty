import SwiftUI
import UniformTypeIdentifiers

/// 右上角特徵流體圓弧玻璃造型 (Fluid Upload Wedge Shape)
/// 沿著視窗右上緣朝左上方優雅延伸，與頂部導覽列流暢融合
public struct FluidUploadWedgeShape: Shape {
    public var expansion: CGFloat // 0.0: 右上角特徵造型 | 1.0: 全視窗展開
    
    public var animatableData: CGFloat {
        get { expansion }
        set { expansion = newValue }
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        
        if expansion >= 0.99 {
            path.addRect(rect)
            return path
        }
        
        let w = rect.width
        let h = rect.height
        
        // Idle 狀態：右上角平滑大圓弧流體造型
        // 起始點：右側邊緣
        // 控制點朝左上方延伸
        let baseWidth: CGFloat = 260 + (w - 260) * expansion
        let baseHeight: CGFloat = 64 + (h - 64) * expansion
        
        let startX = max(0, w - baseWidth)
        let endY = min(h, baseHeight)
        
        path.move(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: startX, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: w, y: endY),
            control: CGPoint(x: startX + baseWidth * 0.45 * (1.0 - expansion), y: endY * 0.85)
        )
        path.closeSubpath()
        
        return path
    }
}

/// 全視窗拖曳放置與流體玻璃展開提示層（DynamicFullWindowDropZone）
public struct DynamicFullWindowDropZone: View {
    public var isDragging: Bool
    public var onDropFiles: ([URL]) -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(isDragging: Bool, onDropFiles: @escaping ([URL]) -> Void) {
        self.isDragging = isDragging
        self.onDropFiles = onDropFiles
    }
    
    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                if isDragging {
                    // 全視窗 Liquid Glass 背景
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .overlay(
                            Rectangle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.accentColor.opacity(0.8), Color.blue.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2.5
                                )
                                .ignoresSafeArea()
                        )
                        .transition(.opacity)
                    
                    // 中央提示卡片
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.16))
                                .frame(width: 88, height: 88)
                            
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundColor(.accentColor)
                        }
                        
                        VStack(spacing: 6) {
                            Text("Drop Files Here")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("Add Your Memories to Noty")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 8) {
                            Label("Photos & Videos", systemImage: "photo.on.rectangle.angled")
                            Text("•")
                            Text("JPG, PNG, HEIC, GIF, WEBP, MOV, MP4")
                            Text("•")
                            Label("100% Local", systemImage: "lock.shield")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                    }
                    .padding(36)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.thinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                }
            }
            .animation(
                reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.78),
                value: isDragging
            )
        }
        .allowsHitTesting(isDragging)
    }
}
