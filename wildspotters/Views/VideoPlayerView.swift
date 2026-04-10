import SwiftUI
import AVFoundation

/// Shared cache so SwiftUI view recreation reuses the same AVPlayer instance.
final class PlayerCache {
    static let shared = PlayerCache()
    private var players: [URL: AVPlayer] = [:]
    private var loopObservers: [URL: Any] = [:]

    func player(for url: URL) -> AVPlayer {
        if let existing = players[url] {
            return existing
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)

        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
        loopObservers[url] = observer

        players[url] = player
        return player
    }

    func removePlayer(for url: URL) {
        if let observer = loopObservers.removeValue(forKey: url) {
            NotificationCenter.default.removeObserver(observer)
        }
        players[url]?.pause()
        players.removeValue(forKey: url)
    }
}

struct VideoPlayerView: UIViewRepresentable {

    let url: URL
    var isActive: Bool = true
    var onSwipeLeft: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onSwipeLeft: onSwipeLeft)
    }

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        let swipe = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipe))
        swipe.direction = .left
        view.addGestureRecognizer(swipe)
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        context.coordinator.onSwipeLeft = onSwipeLeft
        uiView.attach(url: url)
        uiView.setActive(isActive)
    }

    static func dismantleUIView(_ uiView: PlayerUIView, coordinator: Coordinator) {
        uiView.detach()
    }

    final class Coordinator: NSObject {
        var onSwipeLeft: (() -> Void)?

        init(onSwipeLeft: (() -> Void)?) {
            self.onSwipeLeft = onSwipeLeft
        }

        @objc func handleSwipe() {
            onSwipeLeft?()
        }
    }
}

final class PlayerUIView: UIView {

    private var currentURL: URL?
    private var activeState: Bool?
    private var backgroundObserver: Any?
    private var foregroundObserver: Any?

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var avPlayerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private var player: AVPlayer? {
        get { avPlayerLayer.player }
        set { avPlayerLayer.player = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        avPlayerLayer.videoGravity = .resizeAspect
        backgroundColor = .black
        configureAudioSession()
        observeAppLifecycle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            // Audio session config is best-effort; video still plays
        }
    }

    private func observeAppLifecycle() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.player?.pause()
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self?.activeState == true else { return }
            self?.player?.play()
        }
    }

    func attach(url: URL) {
        guard url != currentURL else { return }
        currentURL = url
        activeState = nil
        player = PlayerCache.shared.player(for: url)
    }

    func setActive(_ active: Bool) {
        guard active != activeState else { return }
        activeState = active
        if active {
            player?.play()
        } else {
            player?.pause()
        }
    }

    func detach() {
        activeState = nil
        currentURL = nil
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
    }
}
