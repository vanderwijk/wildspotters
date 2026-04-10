import Foundation

final class APIClient: Sendable {

    static let shared = APIClient()

    private let baseURL = URL(string: "https://wildspotters.nl/wp-json/wildspotters/v1")!
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
        var request = URLRequest(url: baseURL.appendingPathComponent("login"))
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

    func register(firstName: String, lastName: String, email: String, password: String) async throws {
        struct RegistrationRequest: Encodable {
            let firstName: String
            let lastName: String
            let email: String
            let password: String
            enum CodingKeys: String, CodingKey {
                case firstName = "first_name"
                case lastName  = "last_name"
                case email, password
            }
        }
        struct RegistrationResponse: Decodable { let success: Bool? }
        let _: RegistrationResponse = try await post(
            "register",
            body: RegistrationRequest(firstName: firstName, lastName: lastName, email: email, password: password)
        )
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

    // MARK: - Identifications

    func submitIdentification(_ identification: Identification) async throws -> IdentificationPanel? {
        let response: IdentificationResponse = try await post(
            "identifications",
            body: identification,
            authenticated: true
        )
        return response.panel
    }

    // MARK: - Private

    private func get<T: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem] = [],
        authenticated: Bool = false
    ) async throws -> T {
        var url = baseURL.appendingPathComponent(path)
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
        authenticated: Bool = false
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        if authenticated { try applyAuth(&request) }
        return try await perform(request, authenticated: authenticated)
    }

    private func applyAuth(_ request: inout URLRequest) throws {
        guard let token = KeychainService.getToken() else {
            throw APIError.unauthorized
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func perform<T: Decodable>(_ request: URLRequest, isLogin: Bool = false, authenticated: Bool = false) async throws -> T {
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
            if authenticated {
                await MainActor.run { AuthManager.shared.logout() }
            }
            throw APIError.unauthorized
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
}

// MARK: - Internal response types

private struct ServerError: Decodable {
    let message: String
}


