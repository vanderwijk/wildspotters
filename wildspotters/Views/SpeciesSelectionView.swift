import SwiftUI
import UIKit
import Combine

struct SpeciesSelectionView: View {

    let species: [Species]
    let catalog: [Int: CatalogSpecies]
    let isDisabled: Bool
    let dimWhenDisabled: Bool
    let onSelect: (Species) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(species) { item in
                let catalogItem = catalog[item.id]
                Button {
                    onSelect(item)
                } label: {
                    VStack(spacing: 0) {
                        if catalogItem?.imageURL != nil {
                            SpeciesImageView(speciesID: item.id, catalogItem: catalogItem)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                        } else {
                            speciesPlaceholder
                        }

                        Text(item.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color("BrandDarkGray"))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .padding(.horizontal, 4)
                    }
                    .padding([.top, .horizontal], 6)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                .opacity(isDisabled && dimWhenDisabled ? 0.5 : 1)
                .accessibilityLabel(item.displayName)
                .accessibilityHint(String(localized: "accessibility.speciesHint"))
            }
        }
        .padding(.horizontal)
    }

    init(
        species: [Species],
        catalog: [Int: CatalogSpecies],
        isDisabled: Bool,
        dimWhenDisabled: Bool = true,
        onSelect: @escaping (Species) -> Void
    ) {
        self.species = species
        self.catalog = catalog
        self.isDisabled = isDisabled
        self.dimWhenDisabled = dimWhenDisabled
        self.onSelect = onSelect
    }

    private var speciesPlaceholder: some View {
        Color("BrandGreen").opacity(0.15)
            .aspectRatio(1, contentMode: .fill)
            .overlay {
                Image(systemName: "pawprint.fill")
                    .foregroundStyle(Color("BrandGreen").opacity(0.3))
            }
    }
}

private struct SpeciesImageView: View {
    let speciesID: Int
    let catalogItem: CatalogSpecies?

    @StateObject private var localImageLoader = LocalSpeciesImageLoader()

    var body: some View {
        Group {
            if let localImage = localImageLoader.image {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFill()
            } else {
                AsyncImage(url: catalogItem?.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    default:
                        ProgressView()
                            .frame(height: 70)
                    }
                }
            }
        }
        .task(id: speciesID) {
            localImageLoader.loadImage(
                for: speciesID,
                localURL: CatalogStore.shared.localImageURL(for: speciesID)
            )
        }
        .onDisappear {
            localImageLoader.cancel()
        }
    }

    private var placeholder: some View {
        Color("BrandGreen").opacity(0.15)
            .overlay {
                Image(systemName: "pawprint.fill")
                    .foregroundStyle(Color("BrandGreen").opacity(0.3))
            }
    }
}

@MainActor
private final class LocalSpeciesImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    private var loadTask: Task<Void, Never>?
    private var currentLoadToken = UUID()

    func loadImage(for speciesID: Int, localURL: URL?) {
        loadTask?.cancel()
        currentLoadToken = UUID()
        let loadToken = currentLoadToken

        guard let localURL else {
            image = nil
            return
        }

        if let cachedImage = LocalSpeciesImageCache.shared.image(for: speciesID) {
            image = cachedImage
            return
        }

        image = nil
        let imagePath = localURL.path

        loadTask = Task {
            let loadedImage = await Task.detached(priority: .utility) {
                Self.decodeImage(at: imagePath)
            }.value

            guard !Task.isCancelled else { return }
            guard self.currentLoadToken == loadToken else { return }

            self.image = loadedImage
            if let loadedImage {
                LocalSpeciesImageCache.shared.insert(loadedImage, for: speciesID)
            }
        }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }

    nonisolated private static func decodeImage(at path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }
}

@MainActor
private final class LocalSpeciesImageCache {
    static let shared = LocalSpeciesImageCache()

    private let cache = NSCache<NSNumber, UIImage>()

    func image(for speciesID: Int) -> UIImage? {
        cache.object(forKey: NSNumber(value: speciesID))
    }

    func insert(_ image: UIImage, for speciesID: Int) {
        cache.setObject(image, forKey: NSNumber(value: speciesID))
    }
}
