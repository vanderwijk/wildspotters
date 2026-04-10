import Foundation
import Combine

struct CatalogSpecies: Codable, Identifiable, LocalizedSpeciesNameProviding {
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

    var displayName: String { localizedDisplayName }
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
    private let imagesCacheDirectory: URL
    private let imageManifestURL: URL
    private let imagePrefetchConcurrencyLimit = 4
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        session = URLSession(configuration: configuration)

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheURL = caches.appendingPathComponent("species_catalog.json")
        etagURL = caches.appendingPathComponent("species_catalog_etag.txt")
        imagesCacheDirectory = caches.appendingPathComponent("species_images", isDirectory: true)
        imageManifestURL = caches.appendingPathComponent("species_images_manifest.json")
        do {
            try FileManager.default.createDirectory(at: imagesCacheDirectory, withIntermediateDirectories: true)
        } catch {
            assertionFailure("Failed to create species image cache directory: \(error.localizedDescription)")
        }
        loadFromDisk()
    }

    func localImageURL(for speciesID: Int) -> URL? {
        let file = imagesCacheDirectory.appendingPathComponent("\(speciesID).jpg")
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
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
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            if http.statusCode == 304 { return }
            guard http.statusCode == 200 else { return }

            let catalog = try JSONDecoder().decode(CatalogResponse.self, from: data)
            species = Dictionary(uniqueKeysWithValues: catalog.species.map { ($0.id, $0) })

            // Persist catalog
            try? data.write(to: cacheURL)
            let newEtag = http.value(forHTTPHeaderField: "ETag")
            etag = newEtag
            if let newEtag {
                try? newEtag.write(to: etagURL, atomically: true, encoding: .utf8)
            }

            // Pre-fetch images that aren't cached yet
            await prefetchImages(for: catalog.species)
        } catch {
            // Network failure — keep existing cached data
        }
    }

    private func prefetchImages(for speciesList: [CatalogSpecies]) async {
        var manifest = loadImageManifest()
        let pendingDownloads = speciesList.compactMap { item -> PendingImageDownload? in
            guard let remoteURL = item.imageURL else { return nil }

            let remoteURLString = remoteURL.absoluteString
            let destination = imagesCacheDirectory.appendingPathComponent("\(item.id).jpg")
            let cachedURLString = manifest[String(item.id)]
            let fileExists = FileManager.default.fileExists(atPath: destination.path)

            guard !fileExists || cachedURLString != remoteURLString else { return nil }

            return PendingImageDownload(
                speciesID: item.id,
                remoteURL: remoteURL,
                remoteURLString: remoteURLString,
                destination: destination
            )
        }

        guard !pendingDownloads.isEmpty else { return }

        await withTaskGroup(of: (Int, String)?.self) { group in
            var downloadIterator = pendingDownloads.makeIterator()

            for _ in 0..<min(imagePrefetchConcurrencyLimit, pendingDownloads.count) {
                guard let download = downloadIterator.next() else { break }
                group.addTask { await downloadImage(download, session: self.session) }
            }

            for await result in group {
                guard let (speciesID, urlString) = result else { continue }
                manifest[String(speciesID)] = urlString

                if let nextDownload = downloadIterator.next() {
                    group.addTask { await downloadImage(nextDownload, session: self.session) }
                }
            }
        }

        saveImageManifest(manifest)
    }

    private func loadImageManifest() -> [String: String] {
        guard let data = try? Data(contentsOf: imageManifestURL),
              let manifest = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return manifest
    }

    private func saveImageManifest(_ manifest: [String: String]) {
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        try? data.write(to: imageManifestURL)
    }

    private func loadFromDisk() {
        etag = try? String(contentsOf: etagURL, encoding: .utf8)
        guard let data = try? Data(contentsOf: cacheURL),
              let catalog = try? JSONDecoder().decode(CatalogResponse.self, from: data) else { return }
        species = Dictionary(uniqueKeysWithValues: catalog.species.map { ($0.id, $0) })
    }
}

private struct PendingImageDownload {
    let speciesID: Int
    let remoteURL: URL
    let remoteURLString: String
    let destination: URL
}

private func downloadImage(_ pendingDownload: PendingImageDownload, session: URLSession) async -> (Int, String)? {
    guard let data = try? await session.data(from: pendingDownload.remoteURL).0 else {
        return nil
    }

    try? data.write(to: pendingDownload.destination)
    return (pendingDownload.speciesID, pendingDownload.remoteURLString)
}
