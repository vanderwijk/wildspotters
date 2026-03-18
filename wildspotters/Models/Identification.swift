import Foundation

struct Identification: Codable, Sendable {
    let spotID: Int
    let speciesID: Int

    enum CodingKeys: String, CodingKey {
        case spotID = "spot_id"
        case speciesID = "species_id"
    }
}
