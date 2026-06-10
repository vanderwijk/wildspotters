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
    let avatar: ProfileAvatar?

    enum CodingKeys: String, CodingKey {
        case id, email
        case firstName = "first_name"
        case lastName = "last_name"
        case displayName = "display_name"
        case pendingEmail = "pending_email"
        case emailChangePending = "email_change_pending"
        case avatar
    }
}

struct ProfileAvatar: Codable, Sendable, Equatable {
    let url: URL
    let alt: String
    let speciesID: Int

    enum CodingKeys: String, CodingKey {
        case url, alt
        case speciesID = "species_id"
    }
}

struct ProfileUpdateResponse: Codable, Sendable {
    let success: Bool
    let emailChangeRequested: Bool
    let passwordChanged: Bool?
    let token: String?
    let user: ProfileUser

    enum CodingKeys: String, CodingKey {
        case success, token, user
        case emailChangeRequested = "email_change_requested"
        case passwordChanged = "password_changed"
    }
}
