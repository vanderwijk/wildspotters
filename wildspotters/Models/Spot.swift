import Foundation

protocol LocalizedSpeciesNameProviding {
    var name: String { get }
    var englishName: String? { get }
}

extension LocalizedSpeciesNameProviding {
    var localizedDisplayName: String {
        let preferredLanguage = Bundle.main.preferredLocalizations.first ?? "en"
        if preferredLanguage.hasPrefix("nl") {
            return name
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

    enum CodingKeys: String, CodingKey {
        case id
        case videoURL = "video_url"
        case location
        case speciesOptions = "species_options"
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
    }
}

struct SpotLocation: Decodable {
    let id: Int
    let name: String
    let slug: String
}

struct Species: Decodable, Identifiable, Hashable, LocalizedSpeciesNameProviding {
    let id: Int
    let name: String
    let scientificName: String?
    let englishName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case scientificName = "scientific_name"
        case englishName = "english_name"
    }

    var displayName: String { localizedDisplayName }
}
