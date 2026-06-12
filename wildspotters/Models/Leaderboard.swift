import Foundation

struct LeaderboardResponse: Decodable, Sendable {
    let generatedAt: String
    let entries: [LeaderboardEntry]
    let currentUser: LeaderboardCurrentUser

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case entries
        case currentUser = "current_user"
    }
}

struct LeaderboardEntry: Decodable, Sendable, Identifiable {
    let rank: Int
    let userID: Int
    let name: String
    let avatarURL: URL?
    let score: Double
    let confirmed: Int
    let isCurrentUser: Bool

    var id: Int { userID }

    enum CodingKeys: String, CodingKey {
        case rank
        case userID = "user_id"
        case name
        case avatarURL = "avatar_url"
        case score
        case confirmed
        case isCurrentUser = "is_current_user"
    }
}

struct LeaderboardCurrentUser: Decodable, Sendable {
    let rank: Int?
    let score: Double
    let confirmed: Int
    let name: String
    let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case rank
        case score
        case confirmed
        case name
        case avatarURL = "avatar_url"
    }
}

extension LeaderboardEntry {
    var formattedScore: String {
        Self.formatScore(score)
    }

    private static func formatScore(_ score: Double) -> String {
        String(format: "%.1f", score)
    }
}

extension LeaderboardCurrentUser {
    var formattedScore: String {
        String(format: "%.1f", score)
    }
}
