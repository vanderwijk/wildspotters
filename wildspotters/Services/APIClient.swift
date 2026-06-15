import Foundation

final class APIClient: Sendable {

    static let shared = APIClient()
    static let baseURL: URL = {
        guard let url = URL(string: "https://wildspotters.nl/wp-json/wildspotters/v1") else {
            preconditionFailure("Invalid API base URL configuration")
        }
        return url
    }()

    static func endpoint(_ path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }

    /// Default placeholder avatar shown when a user has no avatar set.
    static let fallbackAvatarURL: URL = {
        guard let url = URL(string: "https://wildspotters.nl/wp-content/themes/wildspotters-theme/images/default-avatar.png") else {
            preconditionFailure("Invalid fallback avatar URL configuration")
        }
        return url
    }()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    // MARK: - Auth

    func login(username: String, password: String) async throws -> LoginResponse {
        var request = URLRequest(url: Self.endpoint("login"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        return try await perform(request, isLogin: true)
    }

    func forgotPassword(email: String) async throws {
        struct ForgotPasswordRequest: Encodable { let email: String }
        struct ForgotPasswordResponse: Decodable { let success: Bool? }
        let _: ForgotPasswordResponse = try await post("forgot-password", body: ForgotPasswordRequest(email: email))
    }

    func resetPassword(token: String, login: String?, password: String) async throws {
        struct ResetPasswordRequest: Encodable {
            let token: String
            let key: String
            let login: String?
            let password: String
            let newPassword: String

            enum CodingKeys: String, CodingKey {
                case token, key, login, password
                case newPassword = "new_password"
            }
        }
        struct ResetPasswordResponse: Decodable { let success: Bool? }
        let _: ResetPasswordResponse = try await post(
            "reset-password",
            body: ResetPasswordRequest(
                token: token,
                key: token,
                login: login,
                password: password,
                newPassword: password
            )
        )
    }

    func getProfile() async throws -> ProfileUser {
        struct ProfileResponse: Decodable { let user: ProfileUser }
        let response: ProfileResponse = try await get("profile", authenticated: true)
        return response.user
    }

    func updateProfile(
        firstName: String,
        lastName: String,
        email: String,
        currentPassword: String?,
        newPassword: String? = nil
    ) async throws -> ProfileUpdateResponse {
        struct ProfileUpdateRequest: Encodable {
            let firstName: String
            let lastName: String
            let email: String
            let currentPassword: String?
            let newPassword: String?

            enum CodingKeys: String, CodingKey {
                case firstName = "first_name"
                case lastName = "last_name"
                case email
                case currentPassword = "current_password"
                case newPassword = "new_password"
            }
        }

        let response: ProfileUpdateResponse = try await post(
            "profile",
            body: ProfileUpdateRequest(
                firstName: firstName,
                lastName: lastName,
                email: email,
                currentPassword: currentPassword?.isEmpty == true ? nil : currentPassword,
                newPassword: newPassword?.isEmpty == true ? nil : newPassword
            ),
            authenticated: true,
            logoutOnUnauthorized: false
        )
        try saveProfileTokenIfNeeded(from: response)
        return response
    }

    func updatePassword(currentPassword: String, newPassword: String) async throws -> ProfileUpdateResponse {
        struct PasswordUpdateRequest: Encodable {
            let currentPassword: String
            let newPassword: String

            enum CodingKeys: String, CodingKey {
                case currentPassword = "current_password"
                case newPassword = "new_password"
            }
        }

        let response: ProfileUpdateResponse = try await post(
            "profile",
            body: PasswordUpdateRequest(
                currentPassword: currentPassword,
                newPassword: newPassword
            ),
            authenticated: true,
            logoutOnUnauthorized: false
        )
        try saveProfileTokenIfNeeded(from: response)
        return response
    }

    func deleteProfile(currentPassword: String) async throws {
        struct DeleteProfileRequest: Encodable {
            let currentPassword: String

            enum CodingKeys: String, CodingKey {
                case currentPassword = "current_password"
            }
        }
        struct DeleteProfileResponse: Decodable { let success: Bool? }

        let _: DeleteProfileResponse = try await delete(
            "profile",
            body: DeleteProfileRequest(currentPassword: currentPassword),
            authenticated: true,
            logoutOnUnauthorized: false
        )
    }

    func register(
        firstName: String,
        lastName: String,
        email: String,
        password: String,
        formStartedAt: Int? = nil
    ) async throws {
        struct RegistrationRequest: Encodable {
            let firstName: String
            let lastName: String
            let email: String
            let password: String
            let formStartedAt: Int?
            let registrationSource = "ios"
            enum CodingKeys: String, CodingKey {
                case firstName = "first_name"
                case lastName  = "last_name"
                case email, password
                case formStartedAt = "form_started_at"
                case registrationSource = "registration_source"
            }
        }
        struct RegistrationResponse: Decodable { let success: Bool? }
        let _: RegistrationResponse = try await post(
            "register",
            body: RegistrationRequest(
                firstName: firstName,
                lastName: lastName,
                email: email,
                password: password,
                formStartedAt: formStartedAt
            )
        )
    }

    /// Exchange the activation key from the email link for a login JWT.
    func activateAccount(activationToken: String) async throws -> LoginResponse {
        struct ActivateRequest: Encodable { let token: String }
        return try await post("activate", body: ActivateRequest(token: activationToken))
    }

    // MARK: - Spots

    func fetchNextSpot(excluding ids: [Int] = []) async throws -> Spot? {
        var queryItems: [URLQueryItem] = []
        if !ids.isEmpty {
            let excludeParam = ids.map(String.init).joined(separator: ",")
            queryItems.append(URLQueryItem(name: "exclude", value: excludeParam))
        }
        let response: SpotResponse = try await get("spot-videos/next", queryItems: queryItems, authenticated: true)
        return response.spot
    }

    func fetchSpot(id spotID: Int) async throws -> Spot? {
        let response: SpotResponse = try await get("spot-videos/\(spotID)", authenticated: true)
        return response.spot
    }

    /// Confirms that a bearer token is accepted by the API.
    func validateSession(token: String? = nil) async throws {
        guard let authToken = token ?? KeychainService.getToken(), !authToken.isEmpty else {
            throw APIError.unauthorized
        }

        var request = URLRequest(url: Self.endpoint("profile"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        _ = try await performStatusOnly(request)
    }

    func validateToken(_ token: String) async throws {
        try await validateSession(token: token)
    }

    func fetchComments(for spotID: Int) async throws -> SpotCommentsResponse {
        try await get("spots/\(spotID)/comments", authenticated: true)
    }

    func submitComment(_ content: String, for spotID: Int) async throws -> SpotCommentResponse {
        struct CommentRequest: Encodable {
            let content: String
        }

        return try await post(
            "spots/\(spotID)/comments",
            body: CommentRequest(content: content),
            authenticated: true
        )
    }

    func setFavorite(_ favorite: Bool, for spotID: Int) async throws -> SpotFavoriteResponse {
        struct FavoriteRequest: Encodable {
            let favorite: Bool
        }

        return try await post(
            "spots/\(spotID)/favorite",
            body: FavoriteRequest(favorite: favorite),
            authenticated: true
        )
    }

    // MARK: - Identifications

    func submitIdentification(_ identification: Identification) async throws -> IdentificationPanel? {
        let response: IdentificationResponse = try await post(
            "identifications",
            body: identification,
            authenticated: true
        )
        return response.panel
    }

    // MARK: - Leaderboard

    func fetchLeaderboard(limit: Int = 25) async throws -> LeaderboardResponse {
        let clampedLimit = min(max(limit, 1), 100)
        return try await get(
            "leaderboard",
            queryItems: [URLQueryItem(name: "limit", value: String(clampedLimit))],
            authenticated: true
        )
    }

    // MARK: - Profile overview

    func fetchProfileOverview() async throws -> ProfileOverviewResponse {
        try await get("profile/overview", authenticated: true)
    }

    func setProfileAvatar(speciesID: Int) async throws -> ProfileAvatar? {
        struct SetAvatarRequest: Encodable {
            let speciesID: Int
            enum CodingKeys: String, CodingKey {
                case speciesID = "species_id"
            }
        }

        let response: SetAvatarResponse = try await post(
            "profile/avatar",
            body: SetAvatarRequest(speciesID: speciesID),
            authenticated: true
        )
        return response.avatar
    }

    // MARK: - Catalog

    func fetchSpeciesCatalog(ifNoneMatch etag: String?) async throws -> SpeciesCatalogFetchResult {
        var request = URLRequest(url: Self.endpoint("species-catalog"))
        request.httpMethod = "GET"
        try applyAuth(&request)
        if let etag, !etag.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 304:
            return SpeciesCatalogFetchResult(status: .unchanged)
        case 200...299:
            return SpeciesCatalogFetchResult(
                status: .updated(
                    data: data,
                    etag: http.value(forHTTPHeaderField: "ETag")
                )
            )
        case 401:
            await MainActor.run { AuthManager.shared.logout() }
            throw APIError.unauthorized
        case 403:
            throw APIError.notActivated
        case 429:
            throw APIError.rateLimited
        default:
            let message = try? decoder.decode(ServerError.self, from: data).message
            throw APIError.serverError(statusCode: http.statusCode, message: message)
        }
    }

    // MARK: - Private

    private func get<T: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem] = [],
        authenticated: Bool = false
    ) async throws -> T {
        var url = Self.endpoint(path)
        if !queryItems.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw APIError.invalidResponse
            }
            components.queryItems = queryItems
            guard let componentsURL = components.url else {
                throw APIError.invalidResponse
            }
            url = componentsURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if authenticated { try applyAuth(&request) }
        return try await perform(request, authenticated: authenticated)
    }

    private func post<T: Decodable, B: Encodable>(
        _ path: String,
        body: B,
        authenticated: Bool = false,
        logoutOnUnauthorized: Bool = true
    ) async throws -> T {
        var request = URLRequest(url: Self.endpoint(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        if authenticated { try applyAuth(&request) }
        return try await perform(
            request,
            authenticated: authenticated,
            logoutOnUnauthorized: logoutOnUnauthorized
        )
    }

    private func delete<T: Decodable, B: Encodable>(
        _ path: String,
        body: B,
        authenticated: Bool = false,
        logoutOnUnauthorized: Bool = true
    ) async throws -> T {
        var request = URLRequest(url: Self.endpoint(path))
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        if authenticated { try applyAuth(&request) }
        return try await perform(
            request,
            authenticated: authenticated,
            logoutOnUnauthorized: logoutOnUnauthorized
        )
    }

    private func applyAuth(_ request: inout URLRequest) throws {
        guard let token = KeychainService.getToken() else {
            throw APIError.unauthorized
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func saveProfileTokenIfNeeded(from response: ProfileUpdateResponse) throws {
        guard response.passwordChanged == true, let token = response.token, !token.isEmpty else { return }
        try KeychainService.saveToken(token)
    }

    private func perform<T: Decodable>(
        _ request: URLRequest,
        isLogin: Bool = false,
        authenticated: Bool = false,
        logoutOnUnauthorized: Bool = true
    ) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            break
        case 401:
            if isLogin {
                throw APIError.invalidCredentials
            }
            if authenticated && logoutOnUnauthorized {
                await MainActor.run { AuthManager.shared.logout() }
                throw APIError.unauthorized
            }
            let message = try? decoder.decode(ServerError.self, from: data).message
            throw APIError.serverError(statusCode: http.statusCode, message: message)
        case 403:
            throw APIError.notActivated
        case 409:
            let message = try? decoder.decode(ServerError.self, from: data).message
            if message?.contains("email") == true || message?.contains("exists") == true {
                throw APIError.emailAlreadyExists
            }
            throw APIError.conflict(message)
        case 429:
            throw APIError.rateLimited
        default:
            let message = try? decoder.decode(ServerError.self, from: data).message
            throw APIError.serverError(statusCode: http.statusCode, message: message)
        }

        do {
            return try decoder.decode(T.self, from: data.isEmpty ? Data("{}".utf8) : data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    private func performStatusOnly(_ request: URLRequest) async throws -> HTTPURLResponse {
        let response: URLResponse

        do {
            (_, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return http
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.notActivated
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.serverError(statusCode: http.statusCode, message: nil)
        }
    }
}

// MARK: - Internal response types

struct SpeciesCatalogFetchResult: Sendable {
    enum Status: Sendable {
        case unchanged
        case updated(data: Data, etag: String?)
    }

    let status: Status
}

private struct ServerError: Decodable {
    let message: String
}
