import MapKit
import SwiftUI

struct SpotInfoTray: View {

    let spot: Spot?
    let activePanel: IdentificationViewModel.SpotInfoPanel?
    let commentCount: Int
    let favoriteCount: Int
    let isFavorited: Bool
    let comments: [SpotComment]
    let commentsOpen: Bool
    let isLoadingComments: Bool
    let isSubmittingComment: Bool
    let isUpdatingFavorite: Bool
    let message: String?
    let error: String?
    @Binding var commentDraft: String
    let onSelectPanel: (IdentificationViewModel.SpotInfoPanel) -> Void
    let onClosePanel: () -> Void
    let onRefreshComments: () async -> Void
    let onSubmitComment: () -> Void

    private let contentInset: CGFloat = 20
    private let panelHeight: CGFloat = 340

    var body: some View {
        VStack(spacing: 0) {
            if let spot, let activePanel, activePanel != .likes {
                panelContent(for: activePanel, spot: spot)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Image("FooterGrass")
                .resizable()
                .scaledToFill()
                .frame(height: 50)
                .clipped()
                .allowsHitTesting(false)

            iconBar
        }
        .background(Color.clear)
        .animation(.spring(response: 0.32, dampingFraction: 0.9), value: activePanel)
    }

    private var iconBar: some View {
        HStack(spacing: 28) {
            trayButton(
                panel: .comments,
                icon: "bubble.left.and.bubble.right",
                activeIcon: "bubble.left.and.bubble.right.fill",
                count: commentCount,
                label: String(localized: "spotInfo.comments.title")
            )

            trayButton(
                panel: .location,
                icon: "mappin.and.ellipse",
                activeIcon: "mappin.and.ellipse",
                count: nil,
                label: String(localized: "spotInfo.location.title")
            )

            trayButton(
                panel: .likes,
                icon: isFavorited ? "heart.fill" : "heart",
                activeIcon: "heart.fill",
                count: favoriteCount,
                label: String(localized: "spotInfo.likes.title")
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(Color("BrandDarkGreen"))
    }

    private func trayButton(
        panel: IdentificationViewModel.SpotInfoPanel,
        icon: String,
        activeIcon: String,
        count: Int?,
        label: String
    ) -> some View {
        let isActive = activePanel == panel || (panel == .likes && isFavorited)

        return Button {
            onSelectPanel(panel)
        } label: {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Capsule()
                        .fill(isActive ? Color("BrandBeige") : Color.white.opacity(0.12))

                    if panel == .likes && isUpdatingFavorite {
                        ProgressView()
                            .tint(isActive ? Color("BrandDarkGreen") : .white)
                    } else {
                        Image(systemName: isActive ? activeIcon : icon)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(isActive ? Color("BrandDarkGreen") : .white)
                    }
                }
                .frame(width: 46, height: 40)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(.caption2.bold())
                        .foregroundStyle(isActive ? .white : Color("BrandDarkGreen"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(
                            Capsule()
                                .fill(isActive ? Color("BrandGreen") : Color("BrandBeige"))
                        )
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(spot == nil || (panel == .likes && isUpdatingFavorite))
        .opacity(spot == nil ? 0.45 : 1)
        .accessibilityLabel(label)
        .accessibilityValue(count.map(String.init) ?? "")
    }

    @ViewBuilder
    private func panelContent(for panel: IdentificationViewModel.SpotInfoPanel, spot: Spot) -> some View {
        VStack(spacing: 0) {
            dragHandle

            switch panel {
            case .comments:
                commentsPanel
            case .location:
                locationPanel(for: spot)
            case .likes:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: panelHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color("BrandDarkGreen").opacity(0.96))
                .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var dragHandle: some View {
        Button {
            onClosePanel()
        } label: {
            Capsule()
                .fill(.white.opacity(0.32))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sluit paneel")
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onEnded { value in
                    if value.translation.height > 12 {
                        onClosePanel()
                    }
                }
        )
        .gesture(
            TapGesture()
                .onEnded {
                    onClosePanel()
                }
        )
    }

    private var commentsPanel: some View {
        VStack(spacing: 12) {
            panelHeader(
                title: String(localized: "spotInfo.comments.title"),
                subtitle: String(localized: "spotInfo.comments.subtitle")
            )

            if isLoadingComments {
                ProgressView()
                    .tint(Color("BrandLightGreen"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if comments.isEmpty {
                            emptyState(
                                icon: "bubble.left",
                                text: String(localized: "spotInfo.comments.empty")
                            )
                        } else {
                            ForEach(comments) { comment in
                                commentRow(comment)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .refreshable {
                    await onRefreshComments()
                }
                .frame(maxHeight: .infinity)
            }

            feedbackLine

            if commentsOpen {
                commentComposer
            } else {
                Text("spotInfo.comments.closed")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 20)
            }
        }
        .padding(.horizontal, contentInset)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func commentRow(_ comment: SpotComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(comment.authorName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                if comment.isPending {
                    Text("spotInfo.comments.pendingBadge")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color("BrandDarkGreen"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color("BrandGreen").opacity(0.16), in: Capsule())
                }

                Spacer(minLength: 0)
            }

            Text(comment.content)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var commentComposer: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color("BrandDarkGreen").opacity(0.16), lineWidth: 1)
                    )

                if commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("spotInfo.comments.placeholder")
                        .font(.subheadline)
                        .foregroundStyle(Color("BrandDarkGray").opacity(0.46))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $commentDraft)
                    .font(.subheadline)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 74)

            Button {
                onSubmitComment()
            } label: {
                if isSubmittingComment {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 40, height: 40)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.bold))
                        .frame(width: 40, height: 40)
                }
            }
            .foregroundStyle(.white)
            .background(Color("BrandGreen"), in: Circle())
            .disabled(isSubmittingComment || commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
            .accessibilityLabel(String(localized: "spotInfo.comments.send"))
        }
        .padding(.bottom, 20)
    }

    private func locationPanel(for spot: Spot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                panelHeader(
                    title: spot.location?.name ?? String(localized: "spotInfo.location.title"),
                    subtitle: String(localized: "spotInfo.location.subtitle")
                )

                if let location = spot.location {
                    LocationMapView(location: location)
                        .frame(height: 138)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color("BrandDarkGreen").opacity(0.12), lineWidth: 1)
                        )

                    if let description = location.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.82))
                    }

                    if !location.commonSpecies.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("spotInfo.location.commonSpecies")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color("BrandLightGreen").opacity(0.72))

                            FlowLayout(spacing: 8) {
                                ForEach(location.commonSpecies) { species in
                                    Text(species.displayName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.white.opacity(0.12), in: Capsule())
                                }
                            }
                        }
                    }
                } else {
                    emptyState(
                        icon: "mappin.slash",
                        text: String(localized: "spotInfo.location.empty")
                    )
                }
            }
            .padding(.horizontal, contentInset)
            .padding(.bottom, 20)
        }
    }

    private func panelHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Color("BrandLightGreen").opacity(0.72))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var feedbackLine: some View {
        if let error {
            Text(error)
                .font(.caption.weight(.medium))
                .foregroundStyle(.red.opacity(0.92))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let message {
            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color("BrandLightGreen"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color("BrandLightGreen"))
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, minHeight: 86)
    }
}

private struct LocationMapView: View {

    let location: SpotLocation
    @State private var position: MapCameraPosition

    init(location: SpotLocation) {
        self.location = location
        if let coordinate = location.coordinate {
            _position = State(
                initialValue: .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                )
            )
        } else {
            _position = State(initialValue: .automatic)
        }
    }

    var body: some View {
        if let coordinate = location.coordinate {
            Map(position: $position) {
                Marker(location.name, coordinate: coordinate)
                    .tint(Color("BrandGreen"))
            }
            .mapControls {
                MapCompass()
            }
        } else {
            ZStack {
                Color("BrandGreen").opacity(0.12)
                Image(systemName: "map")
                    .font(.largeTitle)
                    .foregroundStyle(Color("BrandGreen"))
            }
        }
    }
}

private extension SpotLocation {
    var coordinate: CLLocationCoordinate2D? {
        guard let marker else { return nil }
        return CLLocationCoordinate2D(latitude: marker.latitude, longitude: marker.longitude)
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let height = rows.reduce(CGFloat.zero) { partialResult, row in
            partialResult + row.height
        } + CGFloat(max(0, rows.count - 1)) * spacing

        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [FlowRow] {
        var rows: [FlowRow] = []
        var currentItems: [FlowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if proposedWidth > maxWidth, !currentItems.isEmpty {
                rows.append(FlowRow(items: currentItems, height: currentHeight))
                currentItems = [FlowItem(index: index, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(FlowItem(index: index, size: size))
                currentWidth = proposedWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append(FlowRow(items: currentItems, height: currentHeight))
        }

        return rows
    }

    private struct FlowRow {
        let items: [FlowItem]
        let height: CGFloat
    }

    private struct FlowItem {
        let index: Int
        let size: CGSize
    }
}
