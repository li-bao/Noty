import SwiftUI
import AVKit

/// 精緻現代化原生的 AVPlayer 影片播放器
/// 支援播放/暫停、音量控制、進度拖曳、全螢幕、鍵盤控制與精準時長顯示
public struct CustomVideoPlayerView: View {
    public let videoURL: URL
    
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0.0
    @State private var duration: Double = 0.0
    @State private var volume: Double = 1.0
    @State private var isMuted: Bool = false
    @State private var isControlsVisible: Bool = true
    @State private var isSeeking: Bool = false
    @State private var timeObserverToken: Any?
    @State private var endObserverToken: Any?
    
    public init(videoURL: URL) {
        self.videoURL = videoURL
    }
    
    public var body: some View {
        ZStack {
            Color.black
            
            // 底層 AVPlayer 原生畫面
            if let player = player {
                VideoPlayerRepresentable(player: player)
                    .onTapGesture {
                        togglePlayPause()
                    }
            } else {
                ProgressView()
                    .scaleEffect(1.2)
            }
            
            // 懸浮控制覆蓋層（滑鼠靜止自動淡出）
            VStack {
                // 頂部非必要空間
                Spacer()
                
                // 底部播放控制列
                if isControlsVisible {
                    VStack(spacing: 8) {
                        // 進度拖曳條
                        HStack(spacing: 10) {
                            Text(formatTime(currentTime))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                            
                            Slider(
                                value: Binding(
                                    get: { currentTime },
                                    set: { newTime in
                                        currentTime = newTime
                                        seek(to: newTime)
                                    }
                                ),
                                in: 0...max(duration, 0.1)
                            )
                            .accentColor(.accentColor)
                            
                            Text(formatTime(duration))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        // 功能按鈕列
                        HStack(spacing: 18) {
                            // 快退 5 秒
                            Button(action: { seekRelative(-5.0) }) {
                                Image(systemName: "gobackward.5")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                            .help("倒退 5 秒 (左方向鍵)")
                            
                            // 播放 / 暫停按鈕
                            Button(action: togglePlayPause) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)
                            .help("播放 / 暫停 (空白鍵)")
                            
                            // 快進 5 秒
                            Button(action: { seekRelative(5.0) }) {
                                Image(systemName: "goforward.5")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                            .help("前進 5 秒 (右方向鍵)")
                            
                            Spacer()
                            
                            // 音量控制
                            HStack(spacing: 6) {
                                Button(action: toggleMute) {
                                    Image(systemName: isMuted || volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                                
                                Slider(value: $volume, in: 0...1.0) { _ in
                                    player?.volume = Float(volume)
                                    if volume > 0 { isMuted = false }
                                }
                                .frame(width: 70)
                                .accentColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 4)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            teardownPlayer()
        }
        .onHover { isHovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isControlsVisible = isHovering
            }
        }
        // 鍵盤快捷鍵監聽
        .background(
            KeyEventListenerView(
                onSpace: { togglePlayPause() },
                onLeftArrow: { seekRelative(-5.0) },
                onRightArrow: { seekRelative(5.0) }
            )
        )
    }
    
    // MARK: - 播放器生命週期
    private func setupPlayer() {
        let playerItem = AVPlayerItem(url: videoURL)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.volume = Float(volume)
        self.player = newPlayer
        
        // 監聽總時長
        Task {
            if let asset = playerItem.asset as? AVURLAsset {
                if let dur = try? await asset.load(.duration) {
                    let seconds = CMTimeGetSeconds(dur)
                    if !seconds.isNaN && !seconds.isInfinite {
                        await MainActor.run {
                            self.duration = seconds
                        }
                    }
                }
            }
        }
        
        // 週期性更新目前時間
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            if !isSeeking {
                let sec = CMTimeGetSeconds(time)
                if !sec.isNaN {
                    self.currentTime = sec
                }
            }
        }
        
        // 播放結束通知
        endObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak player] _ in
            self.isPlaying = false
            self.currentTime = 0.0
            player?.seek(to: .zero)
        }
    }
    
    private func teardownPlayer() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let endToken = endObserverToken {
            NotificationCenter.default.removeObserver(endToken)
            endObserverToken = nil
        }
        player?.pause()
        player = nil
    }
    
    private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
    
    private func seek(to seconds: Double) {
        guard let player = player else { return }
        isSeeking = true
        let targetTime = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            self.isSeeking = false
        }
    }
    
    private func seekRelative(_ seconds: Double) {
        let target = min(max(currentTime + seconds, 0), duration)
        currentTime = target
        seek(to: target)
    }
    
    private func toggleMute() {
        guard let player = player else { return }
        isMuted.toggle()
        player.isMuted = isMuted
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "00:00" }
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

/// AVPlayerLayer 封裝
struct VideoPlayerRepresentable: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        view.wantsLayer = true
        view.layer = layer
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let layer = nsView.layer as? AVPlayerLayer {
            layer.player = player
            layer.frame = nsView.bounds
        }
    }
}

/// 鍵盤事件監聽組件
struct KeyEventListenerView: NSViewRepresentable {
    let onSpace: () -> Void
    let onLeftArrow: () -> Void
    let onRightArrow: () -> Void
    
    func makeNSView(context: Context) -> KeyEventHandlingView {
        let view = KeyEventHandlingView()
        view.onSpace = onSpace
        view.onLeftArrow = onLeftArrow
        view.onRightArrow = onRightArrow
        return view
    }
    
    func updateNSView(_ nsView: KeyEventHandlingView, context: Context) {
        nsView.onSpace = onSpace
        nsView.onLeftArrow = onLeftArrow
        nsView.onRightArrow = onRightArrow
    }
}

final class KeyEventHandlingView: NSView {
    var onSpace: (() -> Void)?
    var onLeftArrow: (() -> Void)?
    var onRightArrow: (() -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 49: // Space
            onSpace?()
        case 123: // Left Arrow
            onLeftArrow?()
        case 124: // Right Arrow
            onRightArrow?()
        default:
            super.keyDown(with: event)
        }
    }
}
