import SwiftUI
import AVFoundation

struct VideoPlayerView: UIViewRepresentable {

    let url: URL

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView()
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.load(url: url)
    }

    static func dismantleUIView(_ uiView: PlayerUIView, coordinator: ()) {
        uiView.cleanup()
    }
}

final class PlayerUIView: UIView {

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var loopObserver: Any?
    private var currentURL: URL?

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var avPlayerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        avPlayerLayer.videoGravity = .resizeAspectFill
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func load(url: URL) {
        guard url != currentURL else { return }
        currentURL = url

        cleanup()

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        avPlayerLayer.player = newPlayer
        player = newPlayer

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak newPlayer] _ in
            newPlayer?.seek(to: .zero)
            newPlayer?.play()
        }

        newPlayer.play()
    }

    func cleanup() {
        player?.pause()
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        player = nil
        currentURL = nil
    }
}
