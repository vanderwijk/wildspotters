import SwiftUI

@main
struct WildspottersApp: App {

    @StateObject private var authManager = AuthManager.shared
    @State private var showLogin = false
    @State private var activationSuccessMessage: String? = nil
    @State private var passwordResetRequest: PasswordResetRequest? = nil

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
            .sheet(item: $passwordResetRequest) { request in
                ResetPasswordView(
                    token: request.token,
                    login: request.login,
                    onReturnToLogin: {
                        authManager.logout()
                        activationSuccessMessage = String(localized: "resetPassword.loginMessage")
                        showLogin = true
                        passwordResetRequest = nil
                    }
                )
            }
            .onOpenURL { url in
                if let request = Self.passwordResetRequest(from: url) {
                    showLogin = true
                    passwordResetRequest = request
                    return
                }

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

    private static func passwordResetRequest(from url: URL) -> PasswordResetRequest? {
        guard isPasswordResetURL(url) else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let token = queryItems
            .first(where: { ["token", "key"].contains($0.name.lowercased()) })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let token, !token.isEmpty else { return nil }

        let login = queryItems
            .first(where: { ["login", "user_login"].contains($0.name.lowercased()) })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return PasswordResetRequest(token: token, login: login?.isEmpty == true ? nil : login)
    }

    private static func isPasswordResetURL(_ url: URL) -> Bool {
        if url.scheme?.lowercased() == "wildspotters" {
            let host = url.host?.lowercased()
            let path = url.path.lowercased()
            return host == "reset-password"
                || host == "password-reset"
                || host == "reset"
                || path.hasPrefix("/reset-password")
                || path.hasPrefix("/password-reset")
                || path.hasPrefix("/reset")
        }

        if url.scheme?.lowercased() == "https",
           url.host?.lowercased() == "wildspotters.nl" {
            let path = url.path.lowercased()
            let action = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name.lowercased() == "action" })?
                .value?
                .lowercased()

            return path.hasPrefix("/app/reset-password")
                || path.hasPrefix("/app/password-reset")
                || path.hasPrefix("/app/reset")
                || (path == "/wp-login.php" && (action == "rp" || action == "resetpass"))
        }

        return false
    }
}

private struct PasswordResetRequest: Identifiable {
    let id = UUID()
    let token: String
    let login: String?
}
