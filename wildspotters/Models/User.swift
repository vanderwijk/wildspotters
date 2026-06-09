import Foundation

struct LoginResponse: Codable, Sendable {
    let token: String
    let user: User
}

struct User: Codable, Sendable {
    let id: Int
    let name: String
}

struct ProfileUser: Codable, Sendable, Equatable {
    let id: Int
    let firstName: String
    let lastName: String
    let displayName: String
    let email: String
    let pendingEmail: String?
    let emailChangePending: Bool

    enum CodingKeys: String, CodingKey {
        case id, email
        case firstName = "first_name"
        case lastName = "last_name"
        case displayName = "display_name"
        case pendingEmail = "pending_email"
        case emailChangePending = "email_change_pending"
    }
}

struct ProfileUpdateResponse: Codable, Sendable {
    let success: Bool
    let emailChangeRequested: Bool
    let user: ProfileUser

    enum CodingKeys: String, CodingKey {
        case success, user
        case emailChangeRequested = "email_change_requested"
    }
}
