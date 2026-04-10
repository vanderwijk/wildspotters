import SwiftUI
import AVFoundation

/// Shared cache so SwiftUI view recreation reuses the same AVPlayer instance.
@MainActor
final class PlayerCache {
    static let shared = PlayerCache()

    private struct CacheEntry {
        let player: AVPlayer
        let observer: Any
        var activeReferences: Int
        var isPrepared: Bool
    }

    private var entries: [URL: CacheEntry] = [:]

    func retainPlayer(for url: URL) -> AVPlayer {
        var entry = entry(for: url)
        entry.activeReferences += 1
        entries[url] = entry
        return entry.player
    }

    func releasePlayer(for url: URL) {
        guard var entry = entries[url] else { return }
        entry.activeReferences = max(0, entry.activeReferences - 1)
        entries[url] = entry
        removeEntryIfUnused(for: url)
    }

    func preparePlayer(for url: URL) {
        var entry = entry(for: url)
        entry.isPrepared = true
        entries[url] = entry
    }

    func consumePreparedPlayer(for url: URL) {
        guard var entry = entries[url] else { return }
        entry.isPrepared = false
        entries[url] = entry
    }

    func releasePreparedPlayer(for url: URL) {
        guard var entry = entries[url] else { return }
        entry.isPrepared = false
        entries[url] = entry
        removeEntryIfUnused(for: url)
    }

    private func entry(for url: URL) -> CacheEntry {
        if let existing = entries[url] {
            return existing
        }

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = false
        player.currentItem?.preferredForwardBufferDuration = 5

        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        let entry = CacheEntry(player: player, observer: observer, activeReferences: 0, isPrepared: false)
        entries[url] = entry
        return entry
    }

    private func removeEntryIfUnused(for url: URL) {
        guard let entry = entries[url], entry.activeReferences == 0, !entry.isPrepared else { return }
        entry.player.pause()
        NotificationCenter.default.removeObserver(entry.observer)
        entries.removeValue(forKey: url)
    }
}

struct VideoPlayerView: UIViewRepresentable {

    let url: URL
    var isActive: Bool = true

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView()
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.attach(url: url)
        uiView.setActive(isActive)
    }

    static func dismantleUIView(_ uiView: PlayerUIView, coordinator: Void) {
        uiView.detach()
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
        isUserInteractionEnabled = false
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
        releaseCurrentPlayer(clearLayer: true)
        activeState = nil
        currentURL = url
        player = PlayerCache.shared.retainPlayer(for: url)
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
        releaseCurrentPlayer(clearLayer: false)
        activeState = nil
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
    }

    private func releaseCurrentPlayer(clearLayer: Bool) {
        guard let currentURL else { return }
        player?.pause()
        if clearLayer {
            player = nil
        }
        PlayerCache.shared.releasePlayer(for: currentURL)
        self.currentURL = nil
    }
}
