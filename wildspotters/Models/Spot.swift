import Foundation

struct SpotResponse: Decodable, Sendable {
    let spot: Spot?
    let empty: Bool?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let empty = try container.decodeIfPresent(Bool.self, forKey: .empty), empty {
            self.empty = true
            self.spot = nil
        } else {
            self.empty = false
            self.spot = try Spot(from: decoder)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case empty
    }
}

struct Spot: Codable, Sendable, Identifiable {
    let id: Int
    let videoURL: URL
    let speciesOptions: [Species]

    enum CodingKeys: String, CodingKey {
        case id
        case videoURL = "video_url"
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
        speciesOptions = try container.decode([Species].self, forKey: .speciesOptions)
    }
}

struct Species: Codable, Sendable, Identifiable, Hashable {
    let id: Int
    let name: String
}
