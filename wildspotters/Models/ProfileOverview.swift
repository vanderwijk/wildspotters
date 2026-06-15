import Foundation

struct ProfileOverviewResponse: Decodable, Sendable {
    let avatar: ProfileAvatar?
    let stats: ProfileStats
    let collection: [ProfileCollectionItem]
    let likes: [ProfileLikedSpot]
}

struct ProfileStats: Decodable, Sendable {
    let comments: Int
    let likes: Int
    let totalIdentifications: Int
    let confirmed: Int
    let confirmedPercentage: Double

    enum CodingKeys: String, CodingKey {
        case comments, likes, confirmed
        case totalIdentifications = "total_identifications"
        case confirmedPercentage = "confirmed_percentage"
    }
}

struct ProfileCollectionItem: Decodable, Sendable, Identifiable {
    let speciesID: Int
    let name: String
    let scientificName: String?
    let englishName: String?
    let imageURL: URL?
    let isCurrentAvatar: Bool

    var id: Int { speciesID }

    enum CodingKeys: String, CodingKey {
        case speciesID = "species_id"
        case name
        case scientificName = "scientific_name"
        case englishName = "english_name"
        case imageURL = "image_url"
        case isCurrentAvatar = "is_current_avatar"
    }
}

struct ProfileLikedSpot: Decodable, Sendable, Identifiable {
    let spotID: Int
    let title: String
    let thumbnailURL: URL?
    let date: String?
    let deeplink: URL?

    var id: Int { spotID }

    enum CodingKeys: String, CodingKey {
        case spotID = "spot_id"
        case title
        case thumbnailURL = "thumbnail_url"
        case date
        case deeplink
    }
}

struct SetAvatarResponse: Decodable, Sendable {
    let avatar: ProfileAvatar?
}
