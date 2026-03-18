import SwiftUI

@main
struct wildspottersApp: App {

    @StateObject private var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    IdentificationView(authManager: authManager)
                } else {
                    LoginView(authManager: authManager)
                }
            }
            .animation(.default, value: authManager.isAuthenticated)
        }
    }
}
