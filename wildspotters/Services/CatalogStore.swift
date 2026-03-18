import Foundation

struct CatalogSpecies: Codable, Identifiable {
    let id: Int
    let name: String
    let scientificName: String?
    let englishName: String?
    let imageURL: URL?
    let imageSizeURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, name
        case scientificName = "scientific_name"
        case englishName = "english_name"
        case imageURL = "image_url"
        case imageSizeURL = "image_size_url"
    }

    var displayImageURL: URL? {
        imageSizeURL ?? imageURL
    }

    var displayName: String {
        let preferredLanguage = Bundle.main.preferredLocalizations.first ?? "en"
        if preferredLanguage.hasPrefix("nl") {
            return name
        }
        return englishName ?? name
    }
}

private struct CatalogResponse: Decodable {
    let species: [CatalogSpecies]
}

@MainActor
final class CatalogStore: ObservableObject {

    static let shared = CatalogStore()

    @Published private(set) var species: [Int: CatalogSpecies] = [:]

    private var etag: String?
    private let cacheURL: URL
    private let etagURL: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheURL = caches.appendingPathComponent("species_catalog.json")
        etagURL = caches.appendingPathComponent("species_catalog_etag.txt")
        loadFromDisk()
    }

    func refresh() async {
        let url = URL(string: "https://wildspotters.nl/wp-json/wildspotters/v1/species-catalog")!
        var request = URLRequest(url: url)
        if let token = KeychainService.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            if http.statusCode == 304 { return }
            guard http.statusCode == 200 else { return }

            let catalog = try JSONDecoder().decode(CatalogResponse.self, from: data)
            species = Dictionary(uniqueKeysWithValues: catalog.species.map { ($0.id, $0) })

            // Persist
            try? data.write(to: cacheURL)
            let newEtag = http.value(forHTTPHeaderField: "ETag")
            etag = newEtag
            if let newEtag {
                try? newEtag.write(to: etagURL, atomically: true, encoding: .utf8)
            }
        } catch {
            // Network failure — keep existing cached data
        }
    }

    private func loadFromDisk() {
        etag = try? String(contentsOf: etagURL, encoding: .utf8)
        guard let data = try? Data(contentsOf: cacheURL),
              let catalog = try? JSONDecoder().decode(CatalogResponse.self, from: data) else { return }
        species = Dictionary(uniqueKeysWithValues: catalog.species.map { ($0.id, $0) })
    }
}
