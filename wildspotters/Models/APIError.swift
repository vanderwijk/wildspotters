import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case invalidCredentials
    case notActivated
    case emailAlreadyExists
    case rateLimited
    case conflict(String?)
    case serverError(statusCode: Int, message: String?)
    case decodingFailed(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return String(localized: "error.invalidResponse")
        case .unauthorized:
            return String(localized: "error.unauthorized")
        case .invalidCredentials:
            return String(localized: "error.invalidCredentials")
        case .notActivated:
            return String(localized: "error.notActivated")
        case .emailAlreadyExists:
            return String(localized: "error.emailAlreadyExists")
        case .rateLimited:
            return String(localized: "error.rateLimited")
        case .conflict(let message):
            return message ?? String(localized: "error.conflict")
        case .serverError(let statusCode, let message):
            return message ?? String(format: String(localized: "error.serverError"), statusCode)
        case .decodingFailed:
            return String(localized: "error.decodingFailed")
        case .networkError(let error):
            if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                return String(localized: "error.networkOffline")
            }
            return error.localizedDescription
        }
    }
}
