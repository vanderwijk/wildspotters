import Foundation

struct LoginResponse: Codable, Sendable {
    let token: String
    let user: User
}

struct User: Codable, Sendable {
    let id: Int
    let name: String
}
