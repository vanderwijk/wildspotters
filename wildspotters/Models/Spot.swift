import Foundation

protocol LocalizedSpeciesNameProviding {
    var name: String { get }
    var englishName: String? { get }
    var germanName: String? { get }
}

extension LocalizedSpeciesNameProviding {
    var localizedDisplayName: String {
        let preferredLanguage = Bundle.main.preferredLocalizations.first ?? "en"
        if preferredLanguage.hasPrefix("nl") {
            return name
        }
        if preferredLanguage.hasPrefix("de") {
            return germanName ?? englishName ?? name
        }
        return englishName ?? name
    }
}

struct SpotResponse: Decodable {
    let spot: Spot?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let empty = try container.decodeIfPresent(Bool.self, forKey: .empty), empty {
            spot = nil
        } else {
            spot = try Spot(from: decoder)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case empty
    }
}

struct Spot: Decodable, Identifiable {
    let id: Int
    let videoURL: URL
    let location: SpotLocation?
    let speciesOptions: [Species]
    let commentCount: Int
    let favoriteCount: Int
    let isFavorited: Bool
    let userIdentification: SpotUserIdentification?

    enum CodingKeys: String, CodingKey {
        case id
        case videoURL = "video_url"
        case location
        case speciesOptions = "species_options"
        case commentCount = "comment_count"
        case favoriteCount = "favorite_count"
        case isFavorited = "is_favorited"
        case userIdentification = "user_identification"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        let urlString = try container.decode(String.self, forKey: .videoURL)
        guard let url = URL(string: urlString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .videoURL,
                in: container,
                debugDescription: "Invalid video URL: \(urlString)"
            )
        }
        videoURL = url
        location = try container.decodeIfPresent(SpotLocation.self, forKey: .location)
        speciesOptions = try container.decode([Species].self, forKey: .speciesOptions)
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        favoriteCount = try container.decodeIfPresent(Int.self, forKey: .favoriteCount) ?? 0
        isFavorited = try container.decodeIfPresent(Bool.self, forKey: .isFavorited) ?? false
        userIdentification = try container.decodeIfPresent(SpotUserIdentification.self, forKey: .userIdentification)
    }
}

struct SpotUserIdentification: Decodable {
    let speciesID: Int
    let panel: IdentificationPanel?

    enum CodingKeys: String, CodingKey {
        case speciesID = "species_id"
        case panel
    }
}

struct SpotLocation: Decodable {
    let id: Int
    let name: String
    let slug: String
    let description: String?
    let descriptionEN: String?
    let descriptionDE: String?
    let marker: SpotLocationMarker?
    let commonSpecies: [Species]

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description, marker
        case descriptionEN = "description_en"
        case descriptionDE = "description_de"
        case commonSpecies = "common_species"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decode(String.self, forKey: .slug)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        descriptionEN = try container.decodeIfPresent(String.self, forKey: .descriptionEN)
        descriptionDE = try container.decodeIfPresent(String.self, forKey: .descriptionDE)
        marker = try container.decodeIfPresent(SpotLocationMarker.self, forKey: .marker)
        commonSpecies = try container.decodeIfPresent([Species].self, forKey: .commonSpecies) ?? []
    }

    /// Description text in the app's current language, falling back to the
    /// Dutch description (and then English) when no translation is set.
    var localizedDescription: String? {
        let preferredLanguage = Bundle.main.preferredLocalizations.first ?? "en"
        if preferredLanguage.hasPrefix("nl") {
            return description
        }
        if preferredLanguage.hasPrefix("de") {
            return nonEmpty(descriptionDE) ?? nonEmpty(descriptionEN) ?? description
        }
        return nonEmpty(descriptionEN) ?? description
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

struct SpotLocationMarker: Decodable {
    let latitude: Double
    let longitude: Double
}

struct Species: Decodable, Identifiable, Hashable, LocalizedSpeciesNameProviding {
    let id: Int
    let name: String
    let scientificName: String?
    let englishName: String?
    let germanName: String?
    let imageURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case scientificName = "scientific_name"
        case englishName = "name_en"
        case germanName = "name_de"
        case imageURL = "image_url"
    }

    var displayName: String { localizedDisplayName }
}

struct SpotCommentsResponse: Decodable {
    let comments: [SpotComment]
    let commentCount: Int
    let commentsOpen: Bool

    enum CodingKeys: String, CodingKey {
        case comments
        case commentCount = "comment_count"
        case commentsOpen = "comments_open"
    }
}

struct SpotCommentResponse: Decodable {
    let success: Bool
    let comment: SpotComment
    let commentCount: Int
    let commentsOpen: Bool

    enum CodingKeys: String, CodingKey {
        case success, comment
        case commentCount = "comment_count"
        case commentsOpen = "comments_open"
    }
}

struct SpotFavoriteResponse: Decodable {
    let success: Bool
    let isFavorited: Bool
    let favoriteCount: Int

    enum CodingKeys: String, CodingKey {
        case success
        case isFavorited = "is_favorited"
        case favoriteCount = "favorite_count"
    }
}

struct SpotComment: Decodable, Identifiable, Equatable {
    let id: Int
    let authorName: String
    let content: String
    let dateGMT: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, content, status
        case authorName = "author_name"
        case dateGMT = "date_gmt"
    }

    var isPending: Bool {
        status == "pending" || status == "hold"
    }
}
