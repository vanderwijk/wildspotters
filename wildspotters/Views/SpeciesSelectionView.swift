import SwiftUI

struct SpeciesSelectionView: View {

    let species: [Species]
    let catalog: [Int: CatalogSpecies]
    let isDisabled: Bool
    let onSelect: (Species) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 90), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(species) { item in
                let catalogItem = catalog[item.id]
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSelect(item)
                } label: {
                    VStack(spacing: 4) {
                        if catalogItem?.imageURL != nil {
                            SpeciesImageView(speciesID: item.id, catalogItem: catalogItem)
                                .frame(width: 80, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            speciesPlaceholder
                        }

                        Text(item.displayName)
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(height: 28)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.5 : 1)
                .accessibilityLabel(item.displayName)
                .accessibilityHint(String(localized: "accessibility.speciesHint"))
            }
        }
        .padding(.horizontal)
    }

    private var speciesPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color("BrandGreen").opacity(0.3))
            .frame(width: 80, height: 70)
            .overlay {
                Image(systemName: "pawprint.fill")
                    .foregroundStyle(Color("BrandLightGreen").opacity(0.5))
            }
    }
}

private struct SpeciesImageView: View {
    let speciesID: Int
    let catalogItem: CatalogSpecies?

    var body: some View {
        if let localURL = CatalogStore.shared.localImageURL(for: speciesID),
           let uiImage = UIImage(contentsOfFile: localURL.path) {
            Image(uiImage: uiImage)
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

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color("BrandGreen").opacity(0.3))
            .overlay {
                Image(systemName: "pawprint.fill")
                    .foregroundStyle(Color("BrandLightGreen").opacity(0.5))
            }
    }
}
