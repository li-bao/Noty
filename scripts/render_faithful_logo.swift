#!/usr/bin/env swift
import AppKit
import CoreGraphics

func drawFaithfulNotyIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    
    // 0. macOS Squircle Background (Liquid Glass app icon)
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
    
    // Liquid Glass subtle gradient
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
    
    // Inner border highlight
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.setLineWidth(max(1.0, size * 0.012))
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.75).cgColor)
    ctx.strokePath()
    ctx.restoreGState()
    
    // Geometry based on user hand-drawn sketch (media_1794052396103_a3951c65.jpg)
    // Note bounds inside squircle:
    let noteW = size * 0.62
    let noteH = size * 0.68
    let noteX = (size - noteW) * 0.50
    let noteY = (size - noteH) * 0.50
    
    // In CGContext (0,0) is bottom-left
    let minX = noteX
    let maxX = noteX + noteW
    let minY = noteY
    let maxY = noteY + noteH
    
    let lw = max(1.8, size * 0.052) // Stroke width
    let inkColor = NSColor(red: 0.11, green: 0.13, blue: 0.16, alpha: 1.0).cgColor
    
    ctx.saveGState()
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(lw)
    ctx.setStrokeColor(inkColor)
    
    // Corner radii
    let cornerR = noteW * 0.22
    
    // Bottom-Left 'L' geometry:
    // In CGContext:
    // minY is bottom of note, maxY is top of note
    // The L sits at (minX, minY)
    let lHeight = noteH * 0.24  // Vertical arm height
    let lWidth  = noteW * 0.24  // Horizontal foot width
    
    // GAPS: must be coordinate distance = visibleGap + lw
    // visibleGap_Y ~ 0.075 * noteH, visibleGap_X ~ 0.08 * noteW
    let visibleGapY = max(3.0, noteH * 0.075)
    let visibleGapX = max(3.0, noteW * 0.080)
    let coordGapY = visibleGapY + lw
    let coordGapX = visibleGapX + lw
    
    let lTopY = minY + lHeight
    let lRightX = minX + lWidth
    
    // 1. Draw outer frame (counter-clockwise from L top gap, around top, down to bottom right, along bottom to L right gap)
    let leftWallBottomY = lTopY + coordGapY
    let botWallLeftX = lRightX + coordGapX
    
    let framePath = CGMutablePath()
    // Start at bottom of left wall (above the vertical gap)
    framePath.move(to: CGPoint(x: minX, y: leftWallBottomY))
    // Left wall goes up to top-left corner
    framePath.addLine(to: CGPoint(x: minX, y: maxY - cornerR))
    // Top-left rounded corner
    framePath.addArc(tangent1End: CGPoint(x: minX, y: maxY), tangent2End: CGPoint(x: minX + cornerR, y: maxY), radius: cornerR)
    // Top arched edge (subtle dome curve like hand-drawn card)
    let archMidY = maxY + noteH * 0.015
    framePath.addQuadCurve(to: CGPoint(x: maxX - cornerR, y: maxY), control: CGPoint(x: (minX + maxX) * 0.5, y: archMidY))
    // Top-right rounded corner
    framePath.addArc(tangent1End: CGPoint(x: maxX, y: maxY), tangent2End: CGPoint(x: maxX, y: maxY - cornerR), radius: cornerR)
    // Right wall goes down to bottom-right corner
    framePath.addLine(to: CGPoint(x: maxX, y: minY + cornerR))
    // Bottom-right rounded corner
    framePath.addArc(tangent1End: CGPoint(x: maxX, y: minY), tangent2End: CGPoint(x: maxX - cornerR, y: minY), radius: cornerR)
    // Bottom border goes left until the bottom gap before 'L'
    framePath.addLine(to: CGPoint(x: botWallLeftX, y: minY))
    
    ctx.addPath(framePath)
    ctx.strokePath()
    
    // 2. Draw Standalone 'L' at bottom-left corner
    let lPath = CGMutablePath()
    // Start at top of vertical arm of L
    lPath.move(to: CGPoint(x: minX, y: lTopY))
    // Down to bottom-left corner
    lPath.addLine(to: CGPoint(x: minX, y: minY))
    // Right to end of horizontal arm of L
    lPath.addLine(to: CGPoint(x: lRightX, y: minY))
    ctx.addPath(lPath)
    ctx.strokePath()
    
    // 3. Top rule line (horizontal, below top border)
    let topRuleY = maxY - noteH * 0.19
    let ruleInset = noteW * 0.17
    let topRulePath = CGMutablePath()
    topRulePath.move(to: CGPoint(x: minX + ruleInset, y: topRuleY))
    topRulePath.addLine(to: CGPoint(x: maxX - ruleInset, y: topRuleY))
    ctx.addPath(topRulePath)
    ctx.strokePath()
    
    // 4. Bottom rule line (horizontal, above bottom border)
    let botRuleY = minY + noteH * 0.20
    let botRulePath = CGMutablePath()
    botRulePath.move(to: CGPoint(x: minX + ruleInset, y: botRuleY))
    botRulePath.addLine(to: CGPoint(x: maxX - ruleInset, y: botRuleY))
    ctx.addPath(botRulePath)
    ctx.strokePath()
    
    // 5. Side dashes flanking central N
    // Sketch has 2 dashes on left, 2 dashes on right:
    // Upper dash level and lower dash level
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
    // Left upper dash
    dashesPath.move(to: CGPoint(x: leftDashX1, y: upperDashY))
    dashesPath.addLine(to: CGPoint(x: leftDashX2, y: upperDashY))
    // Left lower dash
    dashesPath.move(to: CGPoint(x: leftDashX1, y: lowerDashY))
    dashesPath.addLine(to: CGPoint(x: leftDashX2, y: lowerDashY))
    // Right upper dash
    dashesPath.move(to: CGPoint(x: rightDashX1, y: upperDashY))
    dashesPath.addLine(to: CGPoint(x: rightDashX2, y: upperDashY))
    // Right lower dash
    dashesPath.move(to: CGPoint(x: rightDashX1, y: lowerDashY))
    dashesPath.addLine(to: CGPoint(x: rightDashX2, y: lowerDashY))
    
    ctx.addPath(dashesPath)
    ctx.strokePath()
    
    // 6. Central 'N' drawn as vector strokes (hand-crafted to match the sketch marker style)
    let nHeight = noteH * 0.32
    let nWidth = noteW * 0.21
    let nCenterX = (minX + maxX) * 0.5
    let nLeftX = nCenterX - nWidth * 0.5
    let nRightX = nCenterX + nWidth * 0.5
    let nBottomY = midY - nHeight * 0.5
    let nTopY = midY + nHeight * 0.5
    
    let nPath = CGMutablePath()
    // Left vertical stem: goes down from top-left to bottom-left (slight organic angle)
    nPath.move(to: CGPoint(x: nLeftX, y: nTopY))
    nPath.addLine(to: CGPoint(x: nLeftX, y: nBottomY))
    // Diagonal stroke: from top-left to bottom-right
    nPath.move(to: CGPoint(x: nLeftX, y: nTopY))
    nPath.addLine(to: CGPoint(x: nRightX, y: nBottomY))
    // Right vertical stem: from bottom-right to top-right
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

let testPath = "/Users/libao/.gemini/antigravity/brain/6b54e7f8-afe0-47c3-bc62-be86ff1e956c/faithful_logo_preview_512.png"
let img = drawFaithfulNotyIcon(size: 512)
savePNG(image: img, path: testPath)
print("Saved faithful_logo_preview_512.png")
