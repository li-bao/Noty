#!/usr/bin/env swift
import AppKit
import CoreGraphics

/// 依據使用者最新手繪品牌識別手稿（media_1794052396103_a3951c65.jpg）繪製的 Noty 官方 AppIcon
/// 嚴格遵循手稿特徵：
/// 1. 拱形頂部筆記卡片外框（微拱弧線頂邊、圓潤轉角）
/// 2. 左下角獨立英文字母大寫「L」（原創核心標誌，頂部與右側具備清晰透明間隙，絕不黏合）
/// 3. 上下全寬橫線飾條 (Rule Lines)
/// 4. 中央手繪風向量「N」
/// 5. 「N」兩側雙層水平短劃線飾條（= N =）
func drawNotyIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    
    // 0. macOS 現代風格圓角底圖（圓角膠囊畫布與柔和立體光影）
    let canvasRect = CGRect(x: 0, y: 0, width: size, height: size)
    let squircleR = size * 0.224
    let squircleRect = canvasRect.insetBy(dx: size * 0.03, dy: size * 0.03)
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: squircleR, cornerHeight: squircleR, transform: nil)
    
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.035),
        blur: size * 0.06,
        color: NSColor.black.withAlphaComponent(0.22).cgColor
    )
    
    // 背景底色漸層（極致純淨的 Liquid Glass 漸層）
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        NSColor(red: 0.99, green: 0.99, blue: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.91, green: 0.93, blue: 0.97, alpha: 1.0).cgColor
    ] as CFArray
    if let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.addPath(squirclePath)
        ctx.clip()
        ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
    }
    ctx.restoreGState()
    
    // 柔和微光邊框
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.setLineWidth(max(1.0, size * 0.012))
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.75).cgColor)
    ctx.strokePath()
    ctx.restoreGState()
    
    // 便簽紙幾何尺寸（以手繪手稿 media_1794052396103_a3951c65.jpg 嚴謹還原）
    let noteW = size * 0.62
    let noteH = size * 0.68
    let noteX = (size - noteW) * 0.50
    let noteY = (size - noteH) * 0.50
    
    let minX = noteX
    let maxX = noteX + noteW
    let minY = noteY
    let maxY = noteY + noteH
    
    let lw = max(1.8, size * 0.052)
    let inkColor = NSColor(red: 0.11, green: 0.13, blue: 0.16, alpha: 1.0).cgColor
    
    ctx.saveGState()
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(lw)
    ctx.setStrokeColor(inkColor)
    
    let cornerR = noteW * 0.22
    
    // 左下角大寫 "L" 幾何尺寸
    let lHeight = noteH * 0.24
    let lWidth  = noteW * 0.24
    
    // 間隙物理計算：需補償 round line cap 半徑 (lw/2 + lw/2 = lw)，確保視覺可見間隙永不閉合
    let visibleGapY = max(3.0, noteH * 0.075)
    let visibleGapX = max(3.0, noteW * 0.080)
    let coordGapY = visibleGapY + lw
    let coordGapX = visibleGapX + lw
    
    let lTopY = minY + lHeight
    let lRightX = minX + lWidth
    
    // 1. 便簽外框（逆時鐘自 L 頂部間距處起筆，經左側、微拱形頂部、右上圓角、右側、右下圓角，至 L 右側間距處）
    let leftWallBottomY = lTopY + coordGapY
    let botWallLeftX = lRightX + coordGapX
    
    let framePath = CGMutablePath()
    framePath.move(to: CGPoint(x: minX, y: leftWallBottomY))
    framePath.addLine(to: CGPoint(x: minX, y: maxY - cornerR))
    framePath.addArc(tangent1End: CGPoint(x: minX, y: maxY), tangent2End: CGPoint(x: minX + cornerR, y: maxY), radius: cornerR)
    let archMidY = maxY + noteH * 0.015
    framePath.addQuadCurve(to: CGPoint(x: maxX - cornerR, y: maxY), control: CGPoint(x: (minX + maxX) * 0.5, y: archMidY))
    framePath.addArc(tangent1End: CGPoint(x: maxX, y: maxY), tangent2End: CGPoint(x: maxX, y: maxY - cornerR), radius: cornerR)
    framePath.addLine(to: CGPoint(x: maxX, y: minY + cornerR))
    framePath.addArc(tangent1End: CGPoint(x: maxX, y: minY), tangent2End: CGPoint(x: maxX - cornerR, y: minY), radius: cornerR)
    framePath.addLine(to: CGPoint(x: botWallLeftX, y: minY))
    ctx.addPath(framePath)
    ctx.strokePath()
    
    // 2. 左下角獨立英文字母大寫「L」（手稿靈魂標誌）
    let lPath = CGMutablePath()
    lPath.move(to: CGPoint(x: minX, y: lTopY))
    lPath.addLine(to: CGPoint(x: minX, y: minY))
    lPath.addLine(to: CGPoint(x: lRightX, y: minY))
    ctx.addPath(lPath)
    ctx.strokePath()
    
    // 3. 頂部水平橫線飾條 (Rule Line)
    let topRuleY = maxY - noteH * 0.19
    let ruleInset = noteW * 0.17
    let topRulePath = CGMutablePath()
    topRulePath.move(to: CGPoint(x: minX + ruleInset, y: topRuleY))
    topRulePath.addLine(to: CGPoint(x: maxX - ruleInset, y: topRuleY))
    ctx.addPath(topRulePath)
    ctx.strokePath()
    
    // 4. 底部水平橫線飾條 (Rule Line)
    let botRuleY = minY + noteH * 0.20
    let botRulePath = CGMutablePath()
    botRulePath.move(to: CGPoint(x: minX + ruleInset, y: botRuleY))
    botRulePath.addLine(to: CGPoint(x: maxX - ruleInset, y: botRuleY))
    ctx.addPath(botRulePath)
    ctx.strokePath()
    
    // 5. 中央 N 兩側雙層水平短線飾條 (= N =)
    let midY = (topRuleY + botRuleY) * 0.5
    let dashSpacing = noteH * 0.088
    let upperDashY = midY + dashSpacing
    let lowerDashY = midY - dashSpacing
    
    let dashLength = noteW * 0.14
    let leftDashX1 = minX + ruleInset
    let leftDashX2 = leftDashX1 + dashLength
    
    let rightDashX2 = maxX - ruleInset
    let rightDashX1 = rightDashX2 - dashLength
    
    let dashesPath = CGMutablePath()
    dashesPath.move(to: CGPoint(x: leftDashX1, y: upperDashY))
    dashesPath.addLine(to: CGPoint(x: leftDashX2, y: upperDashY))
    dashesPath.move(to: CGPoint(x: leftDashX1, y: lowerDashY))
    dashesPath.addLine(to: CGPoint(x: leftDashX2, y: lowerDashY))
    dashesPath.move(to: CGPoint(x: rightDashX1, y: upperDashY))
    dashesPath.addLine(to: CGPoint(x: rightDashX2, y: upperDashY))
    dashesPath.move(to: CGPoint(x: rightDashX1, y: lowerDashY))
    dashesPath.addLine(to: CGPoint(x: rightDashX2, y: lowerDashY))
    ctx.addPath(dashesPath)
    ctx.strokePath()
    
    // 6. 中央英文字母「N」（採用手繪圓角向量線條，與手稿整體風格完全統一）
    let nHeight = noteH * 0.32
    let nWidth = noteW * 0.21
    let nCenterX = (minX + maxX) * 0.5
    let nLeftX = nCenterX - nWidth * 0.5
    let nRightX = nCenterX + nWidth * 0.5
    let nBottomY = midY - nHeight * 0.5
    let nTopY = midY + nHeight * 0.5
    
    let nPath = CGMutablePath()
    nPath.move(to: CGPoint(x: nLeftX, y: nTopY))
    nPath.addLine(to: CGPoint(x: nLeftX, y: nBottomY))
    nPath.move(to: CGPoint(x: nLeftX, y: nTopY))
    nPath.addLine(to: CGPoint(x: nRightX, y: nBottomY))
    nPath.move(to: CGPoint(x: nRightX, y: nBottomY))
    nPath.addLine(to: CGPoint(x: nRightX, y: nTopY))
    ctx.addPath(nPath)
    ctx.strokePath()
    
    ctx.restoreGState()
    
    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to encode PNG for \(path)")
        return
    }
    try? pngData.write(to: URL(fileURLWithPath: path))
}

let iconDir = "Noty/Resources/Assets.xcassets/AppIcon.appiconset"

let iconSpecs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

print("Rendering high-res faithful AppIcon sets for Noty...")
for (name, dimension) in iconSpecs {
    let img = drawNotyIcon(size: dimension)
    let target = "\(iconDir)/\(name)"
    savePNG(image: img, path: target)
    print(" - Generated \(name) (\(Int(dimension))x\(Int(dimension)))")
}
print("Done!")
