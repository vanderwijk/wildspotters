import Foundation
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

    func logout() {
        KeychainService.deleteToken()
        isAuthenticated = false
    }

    func handleUnauthorized() {
        KeychainService.deleteToken()
        isAuthenticated = false
    }
}
