import SwiftUI

struct CommunityVerdictPanel: View {

    let panel: IdentificationPanel
    let countdownRemaining: Int
    let countdownDuration: Int
    let onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("identification.communityVerdict")
                .font(.headline)
                .foregroundStyle(.white)

            // Selected species with image
            selectedSpeciesRow

            // Community stats bars
            VStack(spacing: 8) {
                ForEach(panel.communityTopSpecies) { stat in
                    speciesStatRow(stat)
                }
            }

            // Total identifications
            Text(String(localized: "identification.totalIdentifications \(panel.communityTotalIdentifications)"))
                .font(.caption)
                .foregroundStyle(Color("BrandLightGreen").opacity(0.7))

            // Next video button with countdown
            CountdownButton(
                remaining: countdownRemaining,
                duration: countdownDuration,
                action: onAdvance
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("BrandDarkGreen").opacity(0.95))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Selected Species

    private var selectedSpeciesRow: some View {
        HStack(spacing: 12) {
            speciesImage(url: panel.selectedSpecies.imageURL)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "identification.yourChoice"))
                    .font(.caption)
                    .foregroundStyle(Color("BrandLightGreen").opacity(0.7))
                Text(panel.selectedSpecies.displayName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("BrandGreen").opacity(0.2))
        )
    }

    // MARK: - Stat Row

    private func speciesStatRow(_ stat: CommunitySpeciesStat) -> some View {
        HStack(spacing: 10) {
            speciesImage(url: stat.imageURL)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(stat.displayName)
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: 90, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color("BrandLightGreen"))
                        .frame(width: max(geometry.size.width * CGFloat(stat.percentage) / 100, 4))
                }
            }
            .frame(height: 8)

            Text("\(stat.percentage)%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color("BrandLightGreen"))
                .frame(width: 40, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func speciesImage(url: URL?) -> some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    speciesPlaceholder
                default:
                    Color("BrandGreen").opacity(0.3)
                }
            }
        } else {
            speciesPlaceholder
        }
    }

    private var speciesPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color("BrandGreen").opacity(0.3))
            .overlay {
                Image(systemName: "pawprint.fill")
                    .font(.caption2)
                    .foregroundStyle(Color("BrandLightGreen").opacity(0.5))
            }
    }
}

// MARK: - Countdown Button

struct CountdownButton: View {

    let remaining: Int
    let duration: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("identification.nextVideo")
                    .font(.headline)
                    .foregroundStyle(Color("BrandDarkGreen"))

                ZStack {
                    Circle()
                        .stroke(Color("BrandDarkGreen").opacity(0.3), lineWidth: 3)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color("BrandDarkGreen"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: remaining)

                    Text("\(remaining)")
                        .font(.caption2.bold().monospacedDigit())
                        .foregroundStyle(Color("BrandDarkGreen"))
                }
                .frame(width: 28, height: 28)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color("BrandLightGreen"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var progress: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(remaining) / CGFloat(duration)
    }
}
