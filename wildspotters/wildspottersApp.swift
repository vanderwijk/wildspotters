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
                guard let token = Self.activationToken(from: url) else { return }

                Task {
                    do {
                        try await authManager.handleActivationLink(token: token)
                    } catch {
                        activationSuccessMessage = String(localized: "activation.failed")
                        showLogin = true
                    }
                }
            }
        }
    }

    /// Email activation links and legacy custom-scheme deep links.
    private static func activationToken(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let token = components?
            .queryItems?
            .first(where: { $0.name == "token" })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let token, !token.isEmpty else { return nil }

        if url.scheme?.lowercased() == "wildspotters", url.host?.lowercased() == "activated" {
            return token
        }

        if url.scheme?.lowercased() == "https",
           url.host?.lowercased() == "wildspotters.nl",
           url.path.hasPrefix("/app/activate") {
            return token
        }

        return nil
    }
}
