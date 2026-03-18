import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case rateLimited
    case conflict(String?)
    case serverError(statusCode: Int, message: String?)
    case decodingFailed(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            String(localized: "error.invalidResponse")
        case .unauthorized:
            String(localized: "error.unauthorized")
        case .rateLimited:
            String(localized: "error.rateLimited")
        case .conflict(let message):
            message ?? String(localized: "error.conflict")
        case .serverError(let statusCode, let message):
            message ?? String(localized: "error.serverError \(statusCode)")
        case .decodingFailed:
            String(localized: "error.decodingFailed")
        case .networkError(let error):
            error.localizedDescription
        }
    }
}
