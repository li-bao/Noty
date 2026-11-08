import SwiftUI

/// Noty 統一 Liquid Glass 按鈕樣式體系（NotyButtonStyle）
/// 遵循 Apple 原生 Liquid Glass 設計語言：
/// - 膠囊 (Capsule) 或連續超圓角 (Continuous Rounded)
/// - Ultra Thin Material 流體玻璃質感結合微光邊框
/// - Hover / Pressed 動態反饋與 Spring 彈簧反饋
/// - 支援 Reduce Motion 減弱動態與無障礙高對比
public struct NotyPrimaryButtonStyle: ButtonStyle {
    public var height: CGFloat
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(height: CGFloat = NotyDesignSystem.capsuleHeight) {
        self.height = height
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: height)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(isEnabled ? (configuration.isPressed ? 0.80 : 0.95) : 0.40),
                                Color.accentColor.opacity(isEnabled ? (configuration.isPressed ? 0.70 : 0.85) : 0.30)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.35 : 0.10), lineWidth: 0.8)
            )
            .shadow(
                color: Color.accentColor.opacity(isEnabled && !configuration.isPressed ? 0.30 : 0.0),
                radius: 8,
                x: 0,
                y: 3
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .animation(NotyDesignSystem.quickSpring, value: configuration.isPressed)
    }
}

public struct NotySecondaryButtonStyle: ButtonStyle {
    public var height: CGFloat
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(height: CGFloat = NotyDesignSystem.capsuleHeight) {
        self.height = height
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundColor(isEnabled ? .primary : .secondary.opacity(0.6))
            .padding(.horizontal, 14)
            .frame(height: height)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(configuration.isPressed ? 0.25 : 0.12),
                        lineWidth: 0.8
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.05),
                radius: configuration.isPressed ? 2 : 4,
                x: 0,
                y: 1
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .animation(NotyDesignSystem.quickSpring, value: configuration.isPressed)
    }
}

public struct NotyDestructiveButtonStyle: ButtonStyle {
    public var height: CGFloat
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(height: CGFloat = NotyDesignSystem.capsuleHeight) {
        self.height = height
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: height)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.red.opacity(configuration.isPressed ? 0.75 : 0.90),
                                Color.red.opacity(configuration.isPressed ? 0.65 : 0.80)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.30), lineWidth: 0.8)
            )
            .shadow(
                color: Color.red.opacity(isEnabled && !configuration.isPressed ? 0.35 : 0.0),
                radius: 8,
                x: 0,
                y: 3
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .animation(NotyDesignSystem.quickSpring, value: configuration.isPressed)
    }
}

public struct NotyIconButtonStyle: ButtonStyle {
    public var size: CGFloat
    public var isActive: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(size: CGFloat = 32, isActive: Bool = false) {
        self.size = size
        self.isActive = isActive
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.45, weight: .medium))
            .foregroundColor(isActive ? .accentColor : (isEnabled ? .primary : .secondary.opacity(0.5)))
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(
                        isActive
                            ? AnyShapeStyle(Color.accentColor.opacity(colorScheme == .dark ? 0.30 : 0.18))
                            : AnyShapeStyle(.ultraThinMaterial)
                    )
            )
            .overlay(
                Circle()
                    .strokeBorder(
                        isActive
                            ? Color.accentColor.opacity(0.60)
                            : Color.primary.opacity(configuration.isPressed ? 0.25 : 0.10),
                        lineWidth: isActive ? 1.2 : 0.8
                    )
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1.0)
            .animation(NotyDesignSystem.quickSpring, value: configuration.isPressed)
    }
}

public struct NotyFloatingButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.50), Color.white.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .shadow(color: Color.black.opacity(0.20), radius: 14, x: 0, y: 6)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1.0)
            .animation(NotyDesignSystem.quickSpring, value: configuration.isPressed)
    }
}

// MARK: - ButtonStyle View Extensions

public extension ButtonStyle where Self == NotyPrimaryButtonStyle {
    static var notyPrimary: NotyPrimaryButtonStyle { NotyPrimaryButtonStyle() }
    static func notyPrimary(height: CGFloat) -> NotyPrimaryButtonStyle { NotyPrimaryButtonStyle(height: height) }
}

public extension ButtonStyle where Self == NotySecondaryButtonStyle {
    static var notySecondary: NotySecondaryButtonStyle { NotySecondaryButtonStyle() }
    static func notySecondary(height: CGFloat) -> NotySecondaryButtonStyle { NotySecondaryButtonStyle(height: height) }
}

public extension ButtonStyle where Self == NotyDestructiveButtonStyle {
    static var notyDestructive: NotyDestructiveButtonStyle { NotyDestructiveButtonStyle() }
    static func notyDestructive(height: CGFloat) -> NotyDestructiveButtonStyle { NotyDestructiveButtonStyle(height: height) }
}

public extension ButtonStyle where Self == NotyIconButtonStyle {
    static var notyIcon: NotyIconButtonStyle { NotyIconButtonStyle() }
    static func notyIcon(size: CGFloat = 32, isActive: Bool = false) -> NotyIconButtonStyle {
        NotyIconButtonStyle(size: size, isActive: isActive)
    }
}

public extension ButtonStyle where Self == NotyFloatingButtonStyle {
    static var notyFloating: NotyFloatingButtonStyle { NotyFloatingButtonStyle() }
}
