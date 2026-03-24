import SwiftUI

struct SpeciesSelectionView: View {

    let species: [Species]
    let catalog: [Int: CatalogSpecies]
    let isDisabled: Bool
    let onSelect: (Species) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(species) { item in
                let catalogItem = catalog[item.id]
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                            .foregroundStyle(Color(red: 0.196, green: 0.196, blue: 0.196))
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
                .opacity(isDisabled ? 0.5 : 1)
                .accessibilityLabel(item.displayName)
                .accessibilityHint(String(localized: "accessibility.speciesHint"))
            }
        }
        .padding(.horizontal)
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
        Color("BrandGreen").opacity(0.15)
            .overlay {
                Image(systemName: "pawprint.fill")
                    .foregroundStyle(Color("BrandGreen").opacity(0.3))
            }
    }
}
