import Combine
import SwiftUI
import UIKit

/// The app is portrait-only by default. `FullscreenVideoPlayerView` (6.1) temporarily
/// unlocks landscape while presented and locks back to portrait when dismissed.
final class OrientationManager: ObservableObject {
    static let shared = OrientationManager()

    @Published var mask: UIInterfaceOrientationMask = .portrait

    func unlockLandscape() {
        mask = .allButUpsideDown
        requestUpdate()
    }

    func lockPortrait() {
        mask = .portrait
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        requestUpdate()
    }

    private func requestUpdate() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
}

/// Minimal app delegate whose sole purpose is to expose `OrientationManager`'s mask
/// to UIKit, so the fullscreen video player (6.1) can rotate to landscape on demand.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationManager.shared.mask
    }
}
