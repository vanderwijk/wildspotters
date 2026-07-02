import SwiftUI

@main
struct WildspottersApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showLogin = false
    @State private var activationSuccessMessage: String? = nil
    @State private var passwordResetRequest: PasswordResetRequest? = nil
    @State private var pendingSpotID: Int? = nil

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isRestoringSession {
                    SessionRestoreView()
                } else if authManager.isAuthenticated {
                    IdentificationView(
                        authManager: authManager,
                        pendingSpotID: $pendingSpotID
                    )
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
            .animation(.default, value: authManager.isRestoringSession)
            .animation(.default, value: showLogin)
            .task {
                await authManager.restoreSession()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await authManager.validateActiveSessionIfNeeded()
                }
            }
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
                if let spotID = Self.spotID(from: url) {
                    pendingSpotID = spotID
                    return
                }

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

    /// Spot deeplinks: `wildspotters://spot?id=…` or `https://wildspotters.nl/app/spot/…`.
    private static func spotID(from url: URL) -> Int? {
        if url.scheme?.lowercased() == "wildspotters", url.host?.lowercased() == "spot" {
            return spotIDFromQuery(url)
        }

        if url.scheme?.lowercased() == "https",
           url.host?.lowercased() == "wildspotters.nl",
           url.path.lowercased().hasPrefix("/app/spot") {
            if let queryID = spotIDFromQuery(url) {
                return queryID
            }

            let pathComponents = url.path.split(separator: "/").map(String.init)
            if pathComponents.count >= 3,
               pathComponents[0] == "app",
               pathComponents[1] == "spot",
               let pathID = Int(pathComponents[2]) {
                return pathID
            }
        }

        return nil
    }

    private static func spotIDFromQuery(_ url: URL) -> Int? {
        let rawValue = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name.lowercased() == "id" })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let rawValue, let spotID = Int(rawValue), spotID > 0 else {
            return nil
        }

        return spotID
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

private struct SessionRestoreView: View {
    var body: some View {
        ZStack {
            Color("BrandBeige")
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240)

                ProgressView(String(localized: "auth.restoringSession"))
                    .tint(Color("BrandDarkGreen"))
                    .foregroundStyle(Color("BrandDarkGray"))
            }
            .padding(32)
        }
    }
}
