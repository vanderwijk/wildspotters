import SwiftUI

/// Adds pinch-to-zoom (with pan while zoomed, and double-tap to reset) to any view.
/// Used by the inline video player and the fullscreen video player (6.1).
struct PinchToZoomModifier: ViewModifier {
    let maxScale: CGFloat
    var isZoomed: Binding<Bool> = .constant(false)

    @State private var currentScale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let size = proxy.size

            content
                .scaleEffect(currentScale)
                .offset(offset)
                .overlay(
                    // A transparent overlay carries the gesture recognizers. Attaching
                    // gestures directly to a UIViewRepresentable (the video layer) is
                    // unreliable, since its underlying UIView doesn't reliably forward
                    // touches to SwiftUI's gesture system.
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let newScale = lastScale * value
                                    currentScale = min(max(newScale, 1), maxScale)
                                    offset = clampedOffset(offset, scale: currentScale, size: size)
                                    isZoomed.wrappedValue = currentScale > 1
                                }
                                .onEnded { _ in
                                    lastScale = currentScale
                                    offset = clampedOffset(offset, scale: currentScale, size: size)
                                    lastOffset = offset
                                    if currentScale == 1 {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            offset = .zero
                                        }
                                        lastOffset = .zero
                                    }
                                    isZoomed.wrappedValue = currentScale > 1
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    guard currentScale > 1 else { return }
                                    let proposed = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    offset = clampedOffset(proposed, scale: currentScale, size: size)
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
                                    offset = .zero
                                } else {
                                    currentScale = 2
                                    lastScale = 2
                                    offset = clampedOffset(offset, scale: 2, size: size)
                                }
                                lastOffset = offset
                            }
                            isZoomed.wrappedValue = currentScale > 1
                        }
                )
                .clipped()
        }
    }

    /// Keeps the scaled content covering the full frame — no edge can be dragged
    /// inward past the frame boundary, so there's never empty space at the
    /// top/bottom/left/right while zoomed in.
    private func clampedOffset(_ proposed: CGSize, scale: CGFloat, size: CGSize) -> CGSize {
        let maxOffsetX = max(0, (size.width * (scale - 1)) / 2)
        let maxOffsetY = max(0, (size.height * (scale - 1)) / 2)

        return CGSize(
            width: min(max(proposed.width, -maxOffsetX), maxOffsetX),
            height: min(max(proposed.height, -maxOffsetY), maxOffsetY)
        )
    }
}

extension View {
    /// Pinch-to-zoom up to `maxScale`, pan while zoomed, double-tap to toggle zoom.
    /// `isZoomed` is updated to reflect whether the content is currently zoomed in,
    /// so callers can disable conflicting gestures (e.g. swipe-to-next) while zoomed.
    func pinchToZoom(maxScale: CGFloat = 4, isZoomed: Binding<Bool> = .constant(false)) -> some View {
        modifier(PinchToZoomModifier(maxScale: maxScale, isZoomed: isZoomed))
    }
}
