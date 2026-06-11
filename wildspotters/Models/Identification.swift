import Foundation

struct Identification: Codable, Sendable {
    let spotID: Int
    let speciesID: Int
    let source: String

    init(spotID: Int, speciesID: Int, source: String = "ios") {
        self.spotID = spotID
        self.speciesID = speciesID
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case spotID = "spot_id"
        case speciesID = "species_id"
        case source
    }
}
