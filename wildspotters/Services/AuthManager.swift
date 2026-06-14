import Foundation
import Combine

@MainActor
final class AuthManager: ObservableObject {

    static let shared = AuthManager()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var isRestoringSession: Bool

    private var hasCompletedInitialRestore = false
    private var lastActiveValidation: Date?

    /// Minimum interval between foreground session re-validations, to avoid
    /// hitting `/profile` on every brief app switch.
    private static let activeValidationMinInterval: TimeInterval = 60

    private init() {
        isRestoringSession = KeychainService.getToken() != nil
    }

    /// Validates a stored token on cold start before showing the main app.
    func restoreSession() async {
        guard !hasCompletedInitialRestore else { return }
        hasCompletedInitialRestore = true

        guard KeychainService.getToken() != nil else {
            finishRestoring(authenticated: false)
            return
        }

        isRestoringSession = true
        defer { isRestoringSession = false }

        applySessionCheck(await performSessionCheck())
    }

    /// Re-validates the active session when the app returns to the foreground.
    /// Throttled so brief app switches don't each trigger a `/profile` call.
    func validateActiveSessionIfNeeded() async {
        guard isAuthenticated, !isRestoringSession else { return }
        guard KeychainService.getToken() != nil else {
            logout()
            return
        }

        if let lastActiveValidation, Date().timeIntervalSince(lastActiveValidation) < Self.activeValidationMinInterval {
            return
        }
        lastActiveValidation = Date()

        if await performSessionCheck() == .invalid {
            logout()
        }
    }

    func login(username: String, password: String) async throws {
        let response = try await APIClient.shared.login(username: username, password: password)
        try KeychainService.saveToken(response.token)
        isAuthenticated = true
    }

    /// Store a JWT that is already valid (legacy deep links).
    func loginWithToken(_ token: String) async throws {
        try await APIClient.shared.validateSession(token: token)
        try KeychainService.saveToken(token)
        isAuthenticated = true
    }

    /// Activate an account using the key from the email link, then sign in.
    func activateAccount(activationToken: String) async throws {
        let response = try await APIClient.shared.activateAccount(activationToken: activationToken)
        try KeychainService.saveToken(response.token)
        isAuthenticated = true
    }

    /// Handle activation deep links from email or the website.
    func handleActivationLink(token: String) async throws {
        // JWTs contain dots; activation keys from email do not.
        if token.split(separator: ".").count == 3 {
            try await loginWithToken(token)
        } else {
            try await activateAccount(activationToken: token)
        }
    }

    func logout() {
        KeychainService.deleteToken()
        isAuthenticated = false
        isRestoringSession = false
        lastActiveValidation = nil
    }

    private enum SessionCheckResult {
        case valid
        case invalid
        case unreachable
    }

    /// Validates the current keychain token, retrying if the token changes mid-flight.
    private func performSessionCheck() async -> SessionCheckResult {
        guard let token = KeychainService.getToken() else { return .invalid }
        let outcome = await checkSession(token)
        guard KeychainService.getToken() == token else {
            return await performSessionCheck()
        }
        return outcome
    }

    private func applySessionCheck(_ outcome: SessionCheckResult) {
        switch outcome {
        case .valid, .unreachable:
            isAuthenticated = true
            lastActiveValidation = Date()
        case .invalid:
            logout()
        }
    }

    private func checkSession(_ token: String) async -> SessionCheckResult {
        if JWTSession.isExpired(token) {
            return .invalid
        }

        do {
            try await APIClient.shared.validateSession(token: token)
            return .valid
        } catch let error as APIError {
            switch error {
            case .unauthorized, .notActivated:
                return .invalid
            case .networkError:
                return .unreachable
            default:
                return .unreachable
            }
        } catch {
            return .unreachable
        }
    }

    private func finishRestoring(authenticated: Bool) {
        isRestoringSession = false
        isAuthenticated = authenticated
    }
}
