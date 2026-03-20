import SwiftUI

@main
struct wildspottersApp: App {

    @StateObject private var authManager = AuthManager.shared
    @State private var showLogin = false

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    IdentificationView(authManager: authManager)
                } else if showLogin {
                    LoginView(authManager: authManager, onShowRegister: { showLogin = false })
                } else {
                    RegisterView(authManager: authManager, onShowLogin: { showLogin = true })
                }
            }
            .animation(.default, value: authManager.isAuthenticated)
            .animation(.default, value: showLogin)
        }
    }
}
