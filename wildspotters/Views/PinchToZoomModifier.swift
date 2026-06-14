import SwiftUI

/// Adds pinch-to-zoom (with pan while zoomed, and double-tap to reset) to any view.
/// Used by the inline video player and the fullscreen video player (6.1).
struct PinchToZoomModifier: ViewModifier {
    let maxScale: CGFloat

    @State private var currentScale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .scaleEffect(currentScale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let newScale = lastScale * value
                        currentScale = min(max(newScale, 1), maxScale)
                    }
                    .onEnded { _ in
                        lastScale = currentScale
                        if currentScale == 1 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = .zero
                            }
                            lastOffset = .zero
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard currentScale > 1 else { return }
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        guard currentScale > 1 else { return }
                        lastOffset = offset
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if currentScale > 1 {
                        currentScale = 1
                        lastScale = 1
                    } else {
                        currentScale = 2
                        lastScale = 2
                    }
                    offset = .zero
                    lastOffset = .zero
                }
            }
            .clipped()
    }
}

extension View {
    /// Pinch-to-zoom up to `maxScale`, pan while zoomed, double-tap to toggle zoom.
    func pinchToZoom(maxScale: CGFloat = 4) -> some View {
        modifier(PinchToZoomModifier(maxScale: maxScale))
    }
}
