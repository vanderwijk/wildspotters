import SwiftUI

@main
struct WildspottersApp: App {

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
                    RegisterView(onShowLogin: { showLogin = true })
                }
            }
            .animation(.default, value: authManager.isAuthenticated)
            .animation(.default, value: showLogin)
            .onOpenURL { url in
                guard url.scheme == "wildspotters", url.host == "activated" else { return }
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                guard let token = components?.queryItems?.first(where: { $0.name == "token" })?.value else {
                    activationSuccessMessage = String(localized: "activation.success")
                    showLogin = true
                    return
                }

                Task {
                    do {
                        try await authManager.loginWithToken(token)
                    } catch {
                        activationSuccessMessage = String(localized: "activation.success")
                        showLogin = true
                    }
                }
            }
        }
    }
}
