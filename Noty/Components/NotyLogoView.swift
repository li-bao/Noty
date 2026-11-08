import SwiftUI

/// 依據使用者最新手繪品牌識別手稿（media_1794052396103_a3951c65.jpg）嚴謹還原的 Noty 向量品牌識別 Logo
/// 核心元素包含：
/// 1. 拱形頂部便簽外框（微拱弧線頂邊、圓潤轉角）
/// 2. 左下角獨立英文字母大寫「L」（原創核心標誌，頂部與右側具備清晰透明間隙，絕不黏合）
/// 3. 上下全寬橫線飾條 (Rule Lines)
/// 4. 中央手繪風向量「N」
/// 5. 「N」兩側雙層水平短劃線飾條（= N =）
public struct NotyLogoView: View {
    public var size: CGFloat
    public var tintColor: Color?
    
    public init(size: CGFloat = 36, tintColor: Color? = nil) {
        self.size = size
        self.tintColor = tintColor
    }
    
    public var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            
            // 便簽主體幾何矩形（SwiftUI Canvas 座標系：(0,0) 在左上角）
            let noteW = w * 0.68
            let noteH = h * 0.74
            let minX = (w - noteW) * 0.50
            let maxX = minX + noteW
            let minY = (h - noteH) * 0.50
            let maxY = minY + noteH
            
            let cornerR = noteW * 0.22
            let lw = max(1.8, w * 0.054)
            let inkColor = tintColor ?? Color.primary
            
            // 左下角大寫 "L" 幾何尺寸
            let lHeight = noteH * 0.24
            let lWidth  = noteW * 0.24
            
            // 間隙物理計算：需補償 round line cap 半徑 (lw)，確保視覺間隙永不黏合
            let visibleGapY = max(2.4, noteH * 0.075)
            let visibleGapX = max(2.4, noteW * 0.080)
            let coordGapY = visibleGapY + lw
            let coordGapX = visibleGapX + lw
            
            let lTopY = maxY - lHeight
            let lRightX = minX + lWidth
            
            let strokeStyle = StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)
            
            // 1. 便簽外框（自 L 上方左邊緣起筆，經左側、拱形頂部、右上圓角、右側、右下圓角，至 L 右側間隙處）
            let leftWallBottomY = lTopY - coordGapY
            let botWallLeftX = lRightX + coordGapX
            
            var framePath = Path()
            framePath.move(to: CGPoint(x: minX, y: leftWallBottomY))
            framePath.addLine(to: CGPoint(x: minX, y: minY + cornerR))
            framePath.addArc(
                tangent1End: CGPoint(x: minX, y: minY),
                tangent2End: CGPoint(x: minX + cornerR, y: minY),
                radius: cornerR
            )
            let archMidY = minY - noteH * 0.015
            framePath.addQuadCurve(
                to: CGPoint(x: maxX - cornerR, y: minY),
                control: CGPoint(x: (minX + maxX) * 0.5, y: archMidY)
            )
            framePath.addArc(
                tangent1End: CGPoint(x: maxX, y: minY),
                tangent2End: CGPoint(x: maxX, y: minY + cornerR),
                radius: cornerR
            )
            framePath.addLine(to: CGPoint(x: maxX, y: maxY - cornerR))
            framePath.addArc(
                tangent1End: CGPoint(x: maxX, y: maxY),
                tangent2End: CGPoint(x: maxX - cornerR, y: maxY),
                radius: cornerR
            )
            framePath.addLine(to: CGPoint(x: botWallLeftX, y: maxY))
            context.stroke(framePath, with: .color(inkColor.opacity(0.88)), style: strokeStyle)
            
            // 2. 左下角獨立英文字母大寫「L」（原創品牌核心標誌）
            var lPath = Path()
            lPath.move(to: CGPoint(x: minX, y: lTopY))
            lPath.addLine(to: CGPoint(x: minX, y: maxY))
            lPath.addLine(to: CGPoint(x: lRightX, y: maxY))
            context.stroke(lPath, with: .color(inkColor.opacity(0.95)), style: strokeStyle)
            
            // 3. 頂部水平橫線飾條 (Rule Line)
            let topRuleY = minY + noteH * 0.19
            let ruleInset = noteW * 0.17
            var topRulePath = Path()
            topRulePath.move(to: CGPoint(x: minX + ruleInset, y: topRuleY))
            topRulePath.addLine(to: CGPoint(x: maxX - ruleInset, y: topRuleY))
            context.stroke(topRulePath, with: .color(inkColor.opacity(0.84)), style: strokeStyle)
            
            // 4. 底部水平橫線飾條 (Rule Line)
            let botRuleY = maxY - noteH * 0.20
            var botRulePath = Path()
            botRulePath.move(to: CGPoint(x: minX + ruleInset, y: botRuleY))
            botRulePath.addLine(to: CGPoint(x: maxX - ruleInset, y: botRuleY))
            context.stroke(botRulePath, with: .color(inkColor.opacity(0.84)), style: strokeStyle)
            
            // 5. 中央 N 兩側雙層水平短劃線飾條 (= N =)
            let midY = (topRuleY + botRuleY) * 0.5
            let dashSpacing = noteH * 0.088
            let upperDashY = midY - dashSpacing
            let lowerDashY = midY + dashSpacing
            
            let dashLength = noteW * 0.14
            let leftDashX1 = minX + ruleInset
            let leftDashX2 = leftDashX1 + dashLength
            
            let rightDashX2 = maxX - ruleInset
            let rightDashX1 = rightDashX2 - dashLength
            
            var dashesPath = Path()
            dashesPath.move(to: CGPoint(x: leftDashX1, y: upperDashY))
            dashesPath.addLine(to: CGPoint(x: leftDashX2, y: upperDashY))
            dashesPath.move(to: CGPoint(x: leftDashX1, y: lowerDashY))
            dashesPath.addLine(to: CGPoint(x: leftDashX2, y: lowerDashY))
            dashesPath.move(to: CGPoint(x: rightDashX1, y: upperDashY))
            dashesPath.addLine(to: CGPoint(x: rightDashX2, y: upperDashY))
            dashesPath.move(to: CGPoint(x: rightDashX1, y: lowerDashY))
            dashesPath.addLine(to: CGPoint(x: rightDashX2, y: lowerDashY))
            context.stroke(dashesPath, with: .color(inkColor.opacity(0.80)), style: strokeStyle)
            
            // 6. 中央英文字母「N」（採用手繪圓角向量線條，與手稿整體風格完全統一）
            let nHeight = noteH * 0.32
            let nWidth = noteW * 0.21
            let nCenterX = (minX + maxX) * 0.5
            let nLeftX = nCenterX - nWidth * 0.5
            let nRightX = nCenterX + nWidth * 0.5
            let nTopY = midY - nHeight * 0.5
            let nBottomY = midY + nHeight * 0.5
            
            var nPath = Path()
            nPath.move(to: CGPoint(x: nLeftX, y: nTopY))
            nPath.addLine(to: CGPoint(x: nLeftX, y: nBottomY))
            nPath.move(to: CGPoint(x: nLeftX, y: nTopY))
            nPath.addLine(to: CGPoint(x: nRightX, y: nBottomY))
            nPath.move(to: CGPoint(x: nRightX, y: nBottomY))
            nPath.addLine(to: CGPoint(x: nRightX, y: nTopY))
            context.stroke(nPath, with: .color(inkColor.opacity(0.92)), style: strokeStyle)
        }
        .frame(width: size, height: size)
    }
}
