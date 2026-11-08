import SwiftUI
import AppKit

/// 通用高效非同步縮圖檢視組件
public struct AsyncThumbnailView: View {
    public let storedFileName: String
    public let isVideo: Bool
    public var fallbackURL: URL? = nil
    
    @State private var thumbnailImage: NSImage? = nil
    
    public init(storedFileName: String, isVideo: Bool = false, fallbackURL: URL? = nil) {
        self.storedFileName = storedFileName
        self.isVideo = isVideo
        self.fallbackURL = fallbackURL
    }
    
    public var body: some View {
        ZStack {
            if let image = thumbnailImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.secondary.opacity(0.08)
                    .overlay(
                        Image(systemName: isVideo ? "video.fill" : "photo.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.4))
                    )
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        if let cached = ThumbnailService.shared.loadCachedThumbnail(for: storedFileName) {
            self.thumbnailImage = cached
            return
        }
        
        if let url = fallbackURL, !isVideo, let diskImg = NSImage(contentsOf: url) {
            self.thumbnailImage = diskImg
            return
        }
        
        let targetFileName = storedFileName
        Task.detached(priority: .userInitiated) {
            let thumbURL = ThumbnailService.shared.thumbnailURL(for: targetFileName)
            if let img = NSImage(contentsOf: thumbURL) {
                await MainActor.run {
                    self.thumbnailImage = img
                }
            }
        }
    }
}
