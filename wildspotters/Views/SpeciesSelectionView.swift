import SwiftUI

struct SpeciesSelectionView: View {

    let species: [Species]
    let isDisabled: Bool
    let onSelect: (Species) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(species) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        Text(item.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color("BrandGreen").opacity(0.6))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                    .opacity(isDisabled ? 0.5 : 1)
                }
            }
            .padding(.horizontal)
        }
    }
}
