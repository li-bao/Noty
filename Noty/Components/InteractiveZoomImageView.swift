import SwiftUI
import AppKit

/// 支援放大、縮小、平移拖曳與雙擊重設的原生高解析度圖片檢視器
public struct InteractiveZoomImageView: View {
    public let imageURL: URL
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var loadedImage: NSImage?
    @State private var isLoading = true
    
    public init(imageURL: URL) {
        self.imageURL = imageURL
    }
    
    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.clear
                
                if let image = loadedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            // 放大縮小手勢
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    let newScale = scale * delta
                                    scale = min(max(newScale, 1.0), 6.0)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale <= 1.0 {
                                        withAnimation(.spring()) {
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                }
                        )
                        .simultaneousGesture(
                            // 平移拖曳手勢（僅在放大時允許平移）
                            DragGesture()
                                .onChanged { value in
                                    guard scale > 1.0 else { return }
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            // 雙擊快速切換 1x 與 2.5x
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.5
                                }
                            }
                        }
                } else if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("Unable to load full image")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .task(id: imageURL) {
            loadImageEfficiently()
        }
    }
    
    /// 非同步且低記憶體開銷載入完整圖片
    private func loadImageEfficiently() {
        isLoading = true
        scale = 1.0
        offset = .zero
        lastOffset = .zero
        
        Task.detached(priority: .userInitiated) {
            guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
                await MainActor.run { isLoading = false }
                return
            }
            
            // 限制載入最大像素尺寸為 3840 (4K 視窗預覽上限)，兼顧超高畫質與記憶體防護
            let maxDimension: CGFloat = 3840
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension
            ]
            
            if let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                let img = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                await MainActor.run {
                    self.loadedImage = img
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.loadedImage = NSImage(contentsOf: imageURL)
                    self.isLoading = false
                }
            }
        }
    }
}
