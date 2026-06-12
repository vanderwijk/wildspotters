import SwiftUI

struct LeaderboardView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LeaderboardViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BrandBeige")
                    .ignoresSafeArea()

                Group {
                    if viewModel.isLoading && viewModel.response == nil {
                        loadingView
                    } else if let error = viewModel.errorMessage, viewModel.response == nil {
                        errorView(error)
                    } else if let response = viewModel.response {
                        contentView(response)
                    }
                }
            }
            .navigationTitle(String(localized: "leaderboard.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color("BrandBeige"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color("BrandDarkGray"))
                    .accessibilityLabel(String(localized: "accessibility.closePanel"))
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color("BrandGreen"))
            Text("leaderboard.loading")
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

    private func contentView(_ response: LeaderboardResponse) -> some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                currentUserCard(response.currentUser)

                headerSection(generatedAt: response.generatedAt)

                let listEntries = response.entries.filter { !$0.isCurrentUser }

                if listEntries.isEmpty {
                    emptyState
                } else {
                    ForEach(listEntries) { entry in
                        entryRow(entry)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .refreshable {
            await viewModel.load()
        }
    }

    private func currentUserCard(_ user: LeaderboardCurrentUser) -> some View {
        HStack(spacing: 14) {
            avatarView(url: user.avatarURL, name: user.name)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("leaderboard.yourRank")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("BrandDarkGray").opacity(0.58))

                Text(user.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color("BrandDarkGray"))
                    .lineLimit(2)

                Text(
                    String(
                        format: String(localized: "leaderboard.confirmedCount"),
                        user.confirmed
                    )
                )
                .font(.subheadline)
                .foregroundStyle(Color("BrandDarkGray").opacity(0.58))
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text(rankLabel(user.rank))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color("BrandDarkGreen"))
                    .monospacedDigit()

                Text(user.formattedScore)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("BrandGreen"))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color("BrandGreen").opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color("BrandGreen").opacity(0.35), lineWidth: 1)
        )
    }

    private func headerSection(generatedAt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("leaderboard.subtitle")
                .font(.subheadline)
                .foregroundStyle(Color("BrandDarkGray").opacity(0.72))

            if let updatedText = formattedUpdatedAt(generatedAt) {
                Text(updatedText)
                    .font(.caption)
                    .foregroundStyle(Color("BrandDarkGray").opacity(0.52))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy")
                .font(.title)
                .foregroundStyle(Color("BrandGreen"))
            Text("leaderboard.empty")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("BrandDarkGray").opacity(0.72))
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(.top, 24)
    }

    private func entryRow(_ entry: LeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            rankBadge(entry.rank)

            avatarView(url: entry.avatarURL, name: entry.name)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("BrandDarkGray"))
                    .lineLimit(1)

                Text(
                    String(
                        format: String(localized: "leaderboard.confirmedCount"),
                        entry.confirmed
                    )
                )
                .font(.caption)
                .foregroundStyle(Color("BrandDarkGray").opacity(0.58))
            }

            Spacer(minLength: 0)

            Text(entry.formattedScore)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color("BrandDarkGreen"))
                .monospacedDigit()
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
    }

    // MARK: - Components

    @ViewBuilder
    private func rankBadge(_ rank: Int) -> some View {
        ZStack {
            Circle()
                .fill(rankBackground(for: rank))
                .frame(width: 34, height: 34)

            if rank <= 3 {
                Image(systemName: rank == 1 ? "trophy.fill" : "medal.fill")
                    .font(.system(size: rank == 1 ? 15 : 14, weight: .semibold))
                    .foregroundStyle(rankForeground(for: rank))
            } else {
                Text("\(rank)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color("BrandDarkGreen"))
                    .monospacedDigit()
            }
        }
        .frame(width: 34)
        .accessibilityLabel(
            String(format: String(localized: "leaderboard.rankAccessibility"), rank)
        )
    }

    @ViewBuilder
    private func avatarView(url: URL?, name: String) -> some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    initialsAvatar(for: name)
                case .empty:
                    ProgressView()
                        .tint(Color("BrandGreen"))
                @unknown default:
                    initialsAvatar(for: name)
                }
            }
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color("BrandLightGreen").opacity(0.45), lineWidth: 1.5)
            )
        } else {
            initialsAvatar(for: name)
        }
    }

    private func initialsAvatar(for name: String) -> some View {
        ZStack {
            Circle()
                .fill(Color("BrandGreen").opacity(0.16))
            Text(initials(from: name))
                .font(.caption.weight(.bold))
                .foregroundStyle(Color("BrandDarkGreen"))
        }
    }

    // MARK: - Helpers

    private func rankLabel(_ rank: Int?) -> String {
        guard let rank else {
            return String(localized: "leaderboard.noRank")
        }
        return "#\(rank)"
    }

    private func rankBackground(for rank: Int) -> Color {
        switch rank {
        case 1:
            return Color(red: 0.95, green: 0.78, blue: 0.22).opacity(0.28)
        case 2:
            return Color(red: 0.78, green: 0.80, blue: 0.84).opacity(0.45)
        case 3:
            return Color(red: 0.82, green: 0.58, blue: 0.32).opacity(0.28)
        default:
            return Color("BrandGreen").opacity(0.12)
        }
    }

    private func rankForeground(for rank: Int) -> Color {
        switch rank {
        case 1:
            return Color(red: 0.78, green: 0.58, blue: 0.08)
        case 2:
            return Color(red: 0.52, green: 0.56, blue: 0.62)
        case 3:
            return Color(red: 0.68, green: 0.42, blue: 0.18)
        default:
            return Color("BrandDarkGreen")
        }
    }

    private func initials(from name: String) -> String {
        let parts = name
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap(\.first)

        guard !parts.isEmpty else { return "?" }
        return String(parts).uppercased()
    }

    private func formattedUpdatedAt(_ iso: String) -> String? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: iso)

        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: iso)
        }

        guard let date else { return nil }

        let formatted = date.formatted(date: .abbreviated, time: .shortened)
        return String(format: String(localized: "leaderboard.updated"), formatted)
    }
}

struct LeaderboardView_Previews: PreviewProvider {
    static var previews: some View {
        LeaderboardView()
    }
}
