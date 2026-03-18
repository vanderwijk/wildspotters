import Foundation

final class APIClient: Sendable {

    static let shared = APIClient()

    private let baseURL = URL(string: "https://wildspotters.nl/wp-json/wildspotters/v1")!
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
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

    // MARK: - Spots

    func fetchNextSpot() async throws -> Spot? {
        let response: SpotResponse = try await get("spot-videos/next", authenticated: true)
        return response.spot
    }

    // MARK: - Identifications

    func submitIdentification(_ identification: Identification) async throws {
        let _: SuccessResponse = try await post(
            "identifications",
            body: identification,
            authenticated: true
        )
    }

    // MARK: - Private

    private func get<T: Decodable>(
        _ path: String,
        authenticated: Bool = false
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"
        if authenticated { try applyAuth(&request) }
        return try await perform(request)
    }

    private func post<T: Decodable, B: Encodable>(
        _ path: String,
        body: B,
        authenticated: Bool = false
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        if authenticated { try applyAuth(&request) }
        return try await perform(request)
    }

    private func applyAuth(_ request: inout URLRequest) throws {
        guard let token = KeychainService.getToken() else {
            throw APIError.unauthorized
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func perform<T: Decodable>(_ request: URLRequest, isLogin: Bool = false) async throws -> T {
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
            AuthManager.shared.logout()
            throw APIError.unauthorized
        case 409:
            let message = try? decoder.decode(ServerError.self, from: data).message
            throw APIError.conflict(message)
        case 429:
            throw APIError.rateLimited
        default:
            let message = try? decoder.decode(ServerError.self, from: data).message
            throw APIError.serverError(statusCode: http.statusCode, message: message)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
}

// MARK: - Internal response types

private struct ServerError: Decodable {
    let message: String
}

private struct SuccessResponse: Decodable {
    let success: Bool
    let action: String
}

