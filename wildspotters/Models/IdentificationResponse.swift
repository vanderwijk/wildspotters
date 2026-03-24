import Foundation

struct IdentificationResponse: Decodable {
    let success: Bool
    let action: String
    let panel: IdentificationPanel?
}

struct IdentificationPanel: Decodable {
    let selectedSpecies: PanelSpecies
    let communityTopSpecies: [CommunitySpeciesStat]
    let communityTotalIdentifications: Int

    enum CodingKeys: String, CodingKey {
        case selectedSpecies = "selected_species"
        case communityTopSpecies = "community_top_species"
        case communityTotalIdentifications = "community_total_identifications"
    }
}

struct PanelSpecies: Decodable {
    let id: Int
    let name: String
    let scientificName: String?
    let englishName: String?
    let imageURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, name
        case scientificName = "scientific_name"
        case englishName = "english_name"
        case imageURL = "image_url"
    }

    var displayName: String {
        let preferredLanguage = Bundle.main.preferredLocalizations.first ?? "en"
        if preferredLanguage.hasPrefix("nl") {
            return name
        }
        return englishName ?? name
    }
}

struct CommunitySpeciesStat: Decodable, Identifiable {
    let id: Int
    let name: String
    let scientificName: String?
    let englishName: String?
    let percentage: Int
    let imageURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, name, percentage
        case scientificName = "scientific_name"
        case englishName = "english_name"
        case imageURL = "image_url"
    }

    var displayName: String {
        let preferredLanguage = Bundle.main.preferredLocalizations.first ?? "en"
        if preferredLanguage.hasPrefix("nl") {
            return name
        }
        return englishName ?? name
    }
}
