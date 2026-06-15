import SwiftUI

/// Shared "3e/4e niveau" list row: leading icon, title/subtitle, trailing chevron.
/// Used for grouped drilldown navigation rows (Apple HIG style), e.g. profile
/// overview entry points and the "over Wildspotters" panel.
struct DrilldownRow: View {

    let title: String
    var subtitle: String?
    var systemImage: String?
    var avatarURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            if let avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        leadingSystemImage
                    default:
                        Color("BrandDarkGreen").opacity(0.08)
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color("BrandLightGreen").opacity(0.55), lineWidth: 1)
                )
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color("BrandDarkGreen"))
                    .frame(width: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("BrandDarkGray"))
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color("BrandDarkGray").opacity(0.58))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("BrandDarkGray").opacity(0.38))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color("BrandDarkGreen").opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var leadingSystemImage: some View {
        if let systemImage {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color("BrandDarkGreen"))
                .frame(width: 28, height: 28)
        } else {
            Color("BrandDarkGreen").opacity(0.08)
        }
    }
}

/// Groups a list of `DrilldownRow`s with consistent spacing, for use inside
/// a `LazyVStack`/`VStack` on a panel-style background.
struct DrilldownGroup<Content: View>: View {

    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: spacing) {
            content
        }
    }
}

struct DrilldownRow_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color("BrandBeige").ignoresSafeArea()
            DrilldownGroup {
                DrilldownRow(title: "Mijn profiel", subtitle: "Naam, e-mail, wachtwoord", systemImage: "person.crop.circle")
                DrilldownRow(title: "Verzamelde soorten", subtitle: "12 van 48", systemImage: "pawprint")
            }
            .padding()
        }
    }
}
