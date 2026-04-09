import SwiftUI

@main
struct wildspottersApp: App {

    @StateObject private var authManager = AuthManager.shared
    @State private var showLogin = false
    @State private var activationSuccessMessage: String? = nil

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    IdentificationView(authManager: authManager)
                } else if showLogin {
                    LoginView(
                        authManager: authManager,
                        onShowRegister: { showLogin = false },
                        successMessage: activationSuccessMessage
                    )
                } else {
                    RegisterView(authManager: authManager, onShowLogin: { showLogin = true })
                }
            }
            .animation(.default, value: authManager.isAuthenticated)
            .animation(.default, value: showLogin)
            .onOpenURL { url in
                guard url.scheme == "wildspotters", url.host == "activated" else { return }
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                if let token = components?.queryItems?.first(where: { $0.name == "token" })?.value,
                   (try? authManager.loginWithToken(token)) != nil {
                    // token stored — isAuthenticated will flip to true automatically
                } else {
                    activationSuccessMessage = String(localized: "activation.success")
                    showLogin = true
                }
            }
        }
    }
}
