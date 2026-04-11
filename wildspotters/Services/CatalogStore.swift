import Foundation
import Combine
import OSLog

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
    private let logger = Logger(subsystem: "nl.wildspotters.app", category: "CatalogStore")

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        session = URLSession(configuration: configuration)

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        if FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first == nil {
            logger.error("Caches directory could not be resolved. Falling back to temporary directory.")
        }
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
        let url = APIClient.endpoint("species-catalog")
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
            do {
                try data.write(to: cacheURL, options: .atomic)
            } catch {
                logger.error("Failed to persist species catalog cache: \(error.localizedDescription, privacy: .public)")
            }
            let newEtag = http.value(forHTTPHeaderField: "ETag")
            etag = newEtag
            if let newEtag {
                do {
                    try newEtag.write(to: etagURL, atomically: true, encoding: .utf8)
                } catch {
                    logger.error("Failed to persist species catalog ETag: \(error.localizedDescription, privacy: .public)")
                }
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
        let data: Data
        do {
            data = try JSONEncoder().encode(manifest)
        } catch {
            logger.error("Failed to encode image manifest: \(error.localizedDescription, privacy: .public)")
            return
        }

        do {
            try data.write(to: imageManifestURL, options: .atomic)
        } catch {
            logger.error("Failed to persist image manifest: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadFromDisk() {
        do {
            etag = try String(contentsOf: etagURL, encoding: .utf8)
        } catch {
            if !Self.isFileNotFound(error) {
                logger.debug("Unexpected ETag load failure: \(error.localizedDescription, privacy: .public)")
            }
            etag = nil
        }

        let data: Data
        do {
            data = try Data(contentsOf: cacheURL)
        } catch {
            if !Self.isFileNotFound(error) {
                logger.debug("Unexpected catalog cache load failure: \(error.localizedDescription, privacy: .public)")
            }
            return
        }

        let catalog: CatalogResponse
        do {
            catalog = try JSONDecoder().decode(CatalogResponse.self, from: data)
        } catch {
            logger.error("Failed to decode persisted catalog cache: \(error.localizedDescription, privacy: .public)")
            return
        }

        species = Dictionary(uniqueKeysWithValues: catalog.species.map { ($0.id, $0) })
    }

    private static func isFileNotFound(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoSuchFileError
    }
}

private struct PendingImageDownload {
    let speciesID: Int
    let remoteURL: URL
    let remoteURLString: String
    let destination: URL
}

private func downloadImage(_ pendingDownload: PendingImageDownload, session: URLSession) async -> (Int, String)? {
    do {
        let (data, response) = try await session.data(from: pendingDownload.remoteURL)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let mimeType = http.mimeType,
              mimeType.hasPrefix("image/"),
              !data.isEmpty else {
            return nil
        }

        try data.write(to: pendingDownload.destination, options: .atomic)
        return (pendingDownload.speciesID, pendingDownload.remoteURLString)
    } catch {
        return nil
    }
}
