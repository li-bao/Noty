import SwiftUI
import AVKit

/// AVKit 原生影片播放器視圖（NSViewRepresentable）
public struct NativeVideoPlayerView: NSViewRepresentable {
    public let videoURL: URL
    
    public init(videoURL: URL) {
        self.videoURL = videoURL
    }
    
    public func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        let player = AVPlayer(url: videoURL)
        playerView.player = player
        playerView.controlsStyle = .inline
        playerView.showsFullScreenToggleButton = true
        return playerView
    }
    
    public func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player?.currentItem?.asset != AVURLAsset(url: videoURL) {
            nsView.player = AVPlayer(url: videoURL)
        }
    }
    
    public static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
        nsView.player?.pause()
        nsView.player = nil
    }
}
