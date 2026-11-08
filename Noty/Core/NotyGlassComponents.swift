import SwiftUI

/// Noty 原生 Liquid Glass 統一元件庫（NotyGlassComponents）
/// 提供統一規格之容器、分頁、彈窗、篩選膠囊與徽章，杜絕個別 View 自行拼裝破碎樣式

// MARK: - 1. Liquid Glass 內容卡片容器（不侵蝕媒體與文章正文閱讀）
public struct NotyGlassCard<Content: View>: View {
    public var cornerRadius: CGFloat
    public var padding: CGFloat
    public let content: Content
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        cornerRadius: CGFloat = NotyDesignSystem.cardCornerRadius,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.45),
                                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.05),
                radius: 8,
                x: 0,
                y: 3
            )
    }
}

// MARK: - 2. Liquid Glass 膠囊篩選項目 (Filter Chip)
public struct NotyCapsuleChip: View {
    public let title: String
    public var icon: String? = nil
    public var count: Int? = nil
    public var isSelected: Bool
    public var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered: Bool = false
    
    public init(
        title: String,
        icon: String? = nil,
        count: Int? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.count = count
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium, design: .rounded))
                
                if let count = count {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : Color.primary.opacity(0.1))
                        )
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .frame(height: NotyDesignSystem.pillHeight)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(.ultraThinMaterial)
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Color.white.opacity(0.35)
                            : Color.primary.opacity(isHovered ? 0.20 : 0.08),
                        lineWidth: 0.8
                    )
            )
            .shadow(
                color: isSelected ? Color.accentColor.opacity(0.25) : Color.clear,
                radius: 6,
                x: 0,
                y: 2
            )
            .scaleEffect(isHovered && !reduceMotion ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if !reduceMotion {
                withAnimation(NotyDesignSystem.quickSpring) {
                    isHovered = hovering
                }
            }
        }
    }
}

// MARK: - 3. Liquid Glass 浮動狀態列 (Floating Status Pill)
public struct NotyStatusPill: View {
    public let text: String
    public var icon: String? = nil
    public var color: Color = .accentColor
    
    public init(text: String, icon: String? = nil, color: Color = .accentColor) {
        self.text = text
        self.icon = icon
        self.color = color
    }
    
    public var body: some View {
        HStack(spacing: 5) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(0.30), lineWidth: 0.8)
        )
    }
}
