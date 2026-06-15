import SwiftUI

/// Second-level screen reached from the leaderboard by tapping the current
/// user's own row/avatar. Shows profile stats, the collected-species
/// "verzameling" with tap-to-set-avatar, and liked videos with a deeplink
/// back to the relevant spot.
struct ProfileOverviewView: View {

    @StateObject private var viewModel = ProfileOverviewViewModel()
    @Environment(\.dismiss) private var dismiss
    @Binding var isLeaderboardPresented: Bool
    @Binding var isOpeningSpot: Bool
    var onOpenSpot: (Int) -> Void = { _ in }
    var onAvatarChanged: (() -> Void)? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 88, maximum: 120), spacing: 12)
    ]

    private let likeColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            Color("BrandBeige")
                .ignoresSafeArea()

            Group {
                if viewModel.isLoading && viewModel.overview == nil {
                    loadingView
                } else if let error = viewModel.errorMessage, viewModel.overview == nil {
                    errorView(error)
                } else if let overview = viewModel.overview {
                    contentView(overview)
                }
            }
        }
        .navigationTitle(String(localized: "profileOverview.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color("BrandBeige"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .task {
            await viewModel.load()
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color("BrandGreen"))
            Text("profileOverview.loading")
                .font(.subheadline)
                .foregroundStyle(Color("BrandDarkGray").opacity(0.72))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(Color("BrandGreen"))
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color("BrandDarkGray").opacity(0.82))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button(String(localized: "common.retry")) {
                Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("BrandGreen"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func contentView(_ overview: ProfileOverviewResponse) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                statsSection(overview.stats)
                collectionSection(overview)
                likesSection(overview.likes)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .refreshable {
            await viewModel.load()
        }
    }

    // MARK: - Stats

    private func statsSection(_ stats: ProfileStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "profileOverview.statsSection"), systemImage: "chart.bar")

            HStack(spacing: 10) {
                statCard(
                    value: "\(stats.confirmed)/\(stats.totalIdentifications)",
                    label: String(localized: "profileOverview.stats.confirmed")
                )
                statCard(
                    value: "\(Int(stats.confirmedPercentage.rounded()))%",
                    label: String(localized: "profileOverview.stats.confirmedPercentage")
                )
            }

            HStack(spacing: 10) {
                statCard(
                    value: "\(stats.comments)",
                    label: String(localized: "profileOverview.stats.comments")
                )
                statCard(
                    value: "\(stats.likes)",
                    label: String(localized: "profileOverview.stats.likes")
                )
            }
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color("BrandDarkGreen"))
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .foregroundStyle(Color("BrandDarkGray").opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color("BrandDarkGreen").opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Collection

    private func collectionSection(_ overview: ProfileOverviewResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "profileOverview.collectionSection"), systemImage: "pawprint")

            Text("profileOverview.collection.hint")
                .font(.caption)
                .foregroundStyle(Color("BrandDarkGray").opacity(0.62))

            if let avatarErrorMessage = viewModel.avatarErrorMessage {
                Text(avatarErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.82))
            }

            if overview.collection.isEmpty {
                emptyState(
                    systemImage: "pawprint.circle",
                    text: String(localized: "profileOverview.collection.empty")
                )
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(overview.collection) { item in
                        collectionTile(item)
                    }
                }
            }
        }
    }

    private func collectionTile(_ item: ProfileCollectionItem) -> some View {
        let isUpdating = viewModel.updatingAvatarSpeciesID == item.speciesID

        return Button {
            Task {
                if await viewModel.setAvatar(speciesID: item.speciesID) {
                    onAvatarChanged?()
                }
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    speciesImage(url: item.imageURL)
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    item.isCurrentAvatar ? Color("BrandGreen") : Color("BrandLightGreen").opacity(0.45),
                                    lineWidth: item.isCurrentAvatar ? 3 : 1.5
                                )
                        )
                        .opacity(isUpdating ? 0.5 : 1)

                    if item.isCurrentAvatar {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color("BrandGreen"))
                            .background(Circle().fill(Color.white))
                            .offset(x: 4, y: -4)
                    }

                    if isUpdating {
                        ProgressView()
                            .tint(Color("BrandGreen"))
                    }
                }

                Text(item.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("BrandDarkGray"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.updatingAvatarSpeciesID != nil)
        .accessibilityLabel(
            item.isCurrentAvatar
                ? String(localized: "profileOverview.collection.currentAvatar \(item.displayName)")
                : String(localized: "profileOverview.collection.setAvatar \(item.displayName)")
        )
    }

    // MARK: - Likes

    private func likesSection(_ likes: [ProfileLikedSpot]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "profileOverview.likesSection"), systemImage: "heart")

            if likes.isEmpty {
                emptyState(
                    systemImage: "heart",
                    text: String(localized: "profileOverview.likes.empty")
                )
            } else {
                LazyVGrid(columns: likeColumns, spacing: 12) {
                    ForEach(likes) { spot in
                        likeTile(spot)
                    }
                }
            }
        }
    }

    private func likeTile(_ spot: ProfileLikedSpot) -> some View {
        Button {
            openSpot(spot)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geometry in
                    spotThumbnail(url: spot.thumbnailURL)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if !spot.title.isEmpty {
                    Text(spot.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("BrandDarkGray"))
                        .lineLimit(1)
                }

                if let date = spot.date, !date.isEmpty {
                    Text(date)
                        .font(.caption2)
                        .foregroundStyle(Color("BrandDarkGray").opacity(0.58))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func openSpot(_ spot: ProfileLikedSpot) {
        isOpeningSpot = true
        onOpenSpot(spot.spotID)
        dismiss()
        isLeaderboardPresented = false
    }


    // MARK: - Shared components

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color("BrandDarkGray"))
    }

    private func emptyState(systemImage: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(Color("BrandGreen"))
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("BrandDarkGray").opacity(0.72))
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func speciesImage(url: URL?) -> some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    ProgressView().tint(Color("BrandGreen"))
                default:
                    speciesPlaceholder
                }
            }
        } else {
            speciesPlaceholder
        }
    }

    private var speciesPlaceholder: some View {
        ZStack {
            Color("BrandGreen").opacity(0.16)
            Image(systemName: "pawprint.fill")
                .foregroundStyle(Color("BrandDarkGreen"))
        }
    }

    @ViewBuilder
    private func spotThumbnail(url: URL?) -> some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    ProgressView().tint(Color("BrandGreen"))
                default:
                    spotThumbnailPlaceholder
                }
            }
        } else {
            spotThumbnailPlaceholder
        }
    }

    private var spotThumbnailPlaceholder: some View {
        ZStack {
            Color("BrandGreen").opacity(0.16)
            Image(systemName: "video.fill")
                .foregroundStyle(Color("BrandDarkGreen"))
        }
    }
}

struct ProfileOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileOverviewView(isLeaderboardPresented: .constant(true), isOpeningSpot: .constant(false))
        }
    }
}
