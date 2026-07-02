import SwiftUI

/// Fullscreen, landscape-locked video presentation (6.1).
/// - Forces landscape orientation while presented, restores portrait on dismiss.
/// - Persistent close button (no auto-hide).
/// - Pinch-to-zoom + pan, independent from the inline player's zoom state.
struct FullscreenVideoPlayerView: View {
    let url: URL
    let onClose: () -> Void

    @ObservedObject private var orientation = OrientationManager.shared

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            VideoPlayerView(url: url, isActive: true)
                .pinchToZoom(maxScale: 4)
                .ignoresSafeArea()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.4))
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityLabel(String(localized: "accessibility.closeFullscreenVideo"))
        }
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            orientation.unlockLandscape()
        }
        .onDisappear {
            orientation.lockPortrait()
        }
    }
}
