import SwiftUI

/// Noty 原生 Apple Liquid Glass 設計系統（NotyDesignSystem）
/// 遵循 macOS 現代流體玻璃語言：
/// - 材質：Ultra Thin Material 結合動態高光反射與柔和陰影
/// - 造型：全面採用 Capsule（膠囊型）與連續圓角（Continuous Rounded Rectangle）
/// - 交互：Hover 柔光高亮 (Soft Glow)、Spring 微彈性反饋、壓下縮放
/// - 支援：自動適應 Light / Dark / System 外觀，支援 Reduce Motion 減弱動態偏好
public enum NotyDesignSystem {
    // MARK: - Radius & Metrics
    public static let capsuleHeight: CGFloat = 34
    public static let pillHeight: CGFloat = 28
    public static let cardCornerRadius: CGFloat = 18
    public static let modalCornerRadius: CGFloat = 22
    
    // MARK: - Springs
    public static let fluidSpring = Animation.spring(response: 0.35, dampingFraction: 0.75)
    public static let bouncySpring = Animation.spring(response: 0.40, dampingFraction: 0.65)
    public static let quickSpring = Animation.spring(response: 0.22, dampingFraction: 0.85)
}

// MARK: - Liquid Glass Modifiers

public struct LiquidGlassModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var isInteractive: Bool
    @State private var isHovered: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    public init(cornerRadius: CGFloat = NotyDesignSystem.cardCornerRadius, isInteractive: Bool = false) {
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? (isHovered ? 0.25 : 0.12) : (isHovered ? 0.60 : 0.40)),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered && isInteractive ? 1.2 : 0.8
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.30 : (isHovered && isInteractive ? 0.12 : 0.06)),
                radius: isHovered && isInteractive ? 14 : 8,
                x: 0,
                y: isHovered && isInteractive ? 6 : 3
            )
            .onHover { hovering in
                if isInteractive && !reduceMotion {
                    withAnimation(NotyDesignSystem.quickSpring) {
                        isHovered = hovering
                    }
                }
            }
    }
}

public struct LiquidCapsuleModifier: ViewModifier {
    public var isActive: Bool
    public var isInteractive: Bool
    @State private var isHovered: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    public init(isActive: Bool = false, isInteractive: Bool = true) {
        self.isActive = isActive
        self.isInteractive = isInteractive
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                Capsule(style: .continuous)
                    .fill(
                        isActive
                            ? AnyShapeStyle(Color.accentColor.opacity(colorScheme == .dark ? 0.35 : 0.22))
                            : AnyShapeStyle(.ultraThinMaterial)
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        isActive
                            ? Color.accentColor.opacity(0.65)
                            : Color.primary.opacity(isHovered && isInteractive ? 0.25 : 0.10),
                        lineWidth: isActive ? 1.2 : 0.8
                    )
            )
            .scaleEffect(isHovered && isInteractive && !reduceMotion ? 1.02 : 1.0)
            .onHover { hovering in
                if isInteractive && !reduceMotion {
                    withAnimation(NotyDesignSystem.quickSpring) {
                        isHovered = hovering
                    }
                }
            }
    }
}

// MARK: - View Extensions

public extension View {
    func liquidGlass(cornerRadius: CGFloat = NotyDesignSystem.cardCornerRadius, isInteractive: Bool = false) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, isInteractive: isInteractive))
    }
    
    func liquidCapsule(isActive: Bool = false, isInteractive: Bool = true) -> some View {
        modifier(LiquidCapsuleModifier(isActive: isActive, isInteractive: isInteractive))
    }
    
    /// 讓純橫向 ScrollView 自動支援一般滑鼠滾輪上下滾動轉譯為水平滑動
    func horizontalWheelScroll() -> some View {
        modifier(HorizontalWheelScrollModifier())
    }
}

// MARK: - Horizontal Wheel Scroll (支援純滑鼠滾輪橫向滑動選單)

import AppKit

public struct HorizontalWheelScrollModifier: ViewModifier {
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .background(HorizontalWheelScrollHelper())
    }
}

public struct HorizontalWheelScrollHelper: NSViewRepresentable {
    public init() {}
    
    public func makeNSView(context: Context) -> WheelCatcherNSView {
        WheelCatcherNSView()
    }
    
    public func updateNSView(_ nsView: WheelCatcherNSView, context: Context) {}
    
    public class WheelCatcherNSView: NSView {
        override public func scrollWheel(with event: NSEvent) {
            var parent = self.superview
            while let current = parent {
                if let sv = current as? NSScrollView {
                    let deltaY = event.scrollingDeltaY
                    let deltaX = event.scrollingDeltaX
                    
                    if deltaX == 0 && deltaY != 0 {
                        let clipView = sv.contentView
                        var origin = clipView.bounds.origin
                        let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1.0 : 16.0
                        origin.x -= deltaY * multiplier
                        
                        if let doc = sv.documentView {
                            let maxX = max(0, doc.bounds.width - clipView.bounds.width)
                            origin.x = max(0, min(maxX, origin.x))
                        }
                        
                        clipView.scroll(to: origin)
                        sv.reflectScrolledClipView(clipView)
                        return
                    }
                    break
                }
                parent = current.superview
            }
            super.scrollWheel(with: event)
        }
    }
}
