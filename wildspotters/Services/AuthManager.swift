import Combine

@MainActor
final class AuthManager: ObservableObject {

    static let shared = AuthManager()

    @Published private(set) var isAuthenticated = false

    private init() {
        isAuthenticated = KeychainService.getToken() != nil
    }

    func login(username: String, password: String) async throws {
        let response = try await APIClient.shared.login(username: username, password: password)
        try KeychainService.saveToken(response.token)
        isAuthenticated = true
    }

    /// Store a JWT that is already valid (legacy deep links).
    func loginWithToken(_ token: String) async throws {
        try await APIClient.shared.validateToken(token)
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
    }
}
