import SwiftUI
import UIKit

struct IdentificationView: View {

    @ObservedObject var authManager: AuthManager
    @StateObject private var viewModel = IdentificationViewModel()
    @GestureState private var swipeTranslation: CGFloat = 0
    @State private var committedSwipeSpotID: Int?
    @State private var committedSwipeOffset: CGFloat = 0
    @State private var suppressSpeciesTap = false
    @State private var speciesTapResetTask: Task<Void, Never>?
    @State private var isProfileDrawerPresented = false
    @State private var isLeaderboardPresented = false

    private let swipeCommitThreshold: CGFloat = 72
    // Grass (50) + icon bar (40 + 2×12 padding) + a little breathing room.
    // The footer now sits above the bottom safe area, so this no longer includes the home-indicator inset.
    private let collapsedFooterReserveHeight: CGFloat = 126

    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                ZStack {
                    backgroundView(height: geometry.size.height)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissKeyboard()
                        }

                    Group {
                        if viewModel.isLoading && viewModel.currentSpot == nil {
                            ProgressView(String(localized: "identification.loading"))
                                .tint(Color("BrandDarkGreen"))
                                .foregroundStyle(Color("BrandDarkGray"))
                        } else if let spot = viewModel.currentSpot {
                            spotPager(spot, containerWidth: geometry.size.width)
                        } else if viewModel.isEmpty {
                            ScrollView {
                                emptyContent
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(.top, 120)
                            }
                            .refreshable {
                                await viewModel.loadNextSpot()
                            }
                        } else if let error = viewModel.errorMessage {
                            errorContent(error)
                        }
                    }
                    // Dismiss the keyboard on any tap in the content area without
                    // blocking the species buttons underneath.
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            dismissKeyboard()
                        }
                    )
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        Color.clear
                            .frame(height: collapsedFooterReserveHeight)
                            .allowsHitTesting(false)
                    }

                    VStack(spacing: 0) {
                        Spacer()
                        footerBar
                    }
                    .zIndex(8)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color("BrandBeige").opacity(0.9), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 44)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                dismissKeyboard()
                            }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.closeSpotInfoPanel()
                            isLeaderboardPresented = true
                        } label: {
                            Image(systemName: isLeaderboardPresented ? "trophy.fill" : "trophy")
                                .font(.title3.weight(.semibold))
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color("BrandDarkGray"))
                        .accessibilityLabel(String(localized: "spotInfo.leaderboard.title"))
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.closeSpotInfoPanel()
                            isProfileDrawerPresented = true
                        } label: {
                            Image(systemName: "person.crop.circle")
                                .font(.title3.weight(.semibold))
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color("BrandDarkGray"))
                        .accessibilityLabel(String(localized: "accessibility.openProfile"))
                    }
                }
                .sheet(isPresented: $isLeaderboardPresented) {
                    LeaderboardView()
                }
                .sheet(isPresented: $isProfileDrawerPresented) {
                    ProfileDrawerView(authManager: authManager)
                }
                .task {
                    await viewModel.loadInitial()
                }
                .onDisappear {
                    speciesTapResetTask?.cancel()
                    viewModel.tearDown()
                }
            }
        }
    }

    // MARK: - Keyboard

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }

    // MARK: - Footer

    private var footerBar: some View {
        SpotInfoTray(
            spot: viewModel.currentSpot,
            activePanel: viewModel.activeSpotInfoPanel,
            commentCount: viewModel.commentCount,
            favoriteCount: viewModel.favoriteCount,
            isFavorited: viewModel.isFavorited,
            comments: viewModel.spotComments,
            commentsOpen: viewModel.commentsOpen,
            isLoadingComments: viewModel.isLoadingComments,
            isSubmittingComment: viewModel.isSubmittingComment,
            isUpdatingFavorite: viewModel.isUpdatingFavorite,
            message: viewModel.spotInfoMessage,
            error: viewModel.spotInfoError,
            commentDraft: $viewModel.commentDraft,
            onSelectPanel: { panel in
                Task { await viewModel.toggleSpotInfoPanel(panel) }
            },
            onClosePanel: {
                viewModel.closeSpotInfoPanel()
            },
            onRefreshComments: {
                await viewModel.refreshComments()
            },
            onSubmitComment: {
                Task { await viewModel.submitComment() }
            }
        )
    }

    // MARK: - Pager

    private func spotPager(_ spot: Spot, containerWidth: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            if let nextSpot = viewModel.upcomingSpot, nextSpot.id != spot.id {
                // Intentionally render the full incoming card for a seamless swipe handoff without pop-in.
                spotContent(nextSpot, isPreview: true, containerWidth: containerWidth)
                    .offset(x: nextCardOffset(containerWidth: containerWidth))
                    .allowsHitTesting(false)
            }

            spotContent(spot, containerWidth: containerWidth)
                .id(spot.id)

            if viewModel.isAdvancing {
                ProgressView(String(localized: "identification.loading"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            // Community verdict panel overlay
            if viewModel.shouldShowCommunityVerdictPanel {
                CommunityVerdictPanel(
                    panelState: viewModel.panelState,
                    catalogStore: viewModel.catalogStore,
                    countdownRemaining: viewModel.countdownRemaining,
                    countdownDuration: viewModel.countdownDuration,
                    onAdvance: {
                        Task { await viewModel.advanceToNextSpot() }
                    },
                    onClose: {
                        viewModel.hideCommunityVerdictPanel()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.shouldShowCommunityVerdictPanel)
    }

    // MARK: - Subviews

    private func spotContent(_ spot: Spot, isPreview: Bool = false, containerWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            VideoPlayerView(
                url: spot.videoURL,
                isActive: !isPreview && !viewModel.isPanelVisible && !viewModel.isAdvancing
            )
            .aspectRatio(16/9, contentMode: .fit)
            .accessibilityLabel(String(localized: "accessibility.videoPlayer"))

            ScrollView {
                VStack(spacing: 12) {
                    Text("identification.question")
                        .font(.headline)
                        .foregroundStyle(Color("BrandDarkGray"))

                    SpeciesSelectionView(
                        species: viewModel.selectableSpecies(for: spot),
                        catalog: viewModel.catalogStore.species,
                        isDisabled: !isSpeciesSelectionEnabled,
                        dimWhenDisabled: false,
                    ) { selected in
                        guard isSpeciesSelectionEnabled else { return }
                        Task {
                            await viewModel.submitIdentification(species: selected)
                        }
                    }
                    .allowsHitTesting(isSpeciesSelectionEnabled)
                    .accessibilityHidden(!isSpeciesSelectionEnabled)
                }
                .padding(.vertical, 16)
            }
            .scrollDisabled(isSwipeTransitionActive)
        }
        .background(Color("BrandBeige"))
        .offset(x: isPreview ? 0 : cardOffset)
        .opacity(isPreview ? 1 : cardOpacity)
        .contentShape(Rectangle())
        .simultaneousGesture(nextSpotSwipeGesture(containerWidth: containerWidth))
        .allowsHitTesting(!viewModel.isAdvancing)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.86), value: swipeTranslation)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.86), value: committedSwipeOffset)
    }

    private func nextSpotSwipeGesture(containerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 30)
            .onChanged { value in
                if shouldSuppressSpeciesTap(for: value) {
                    speciesTapResetTask?.cancel()
                    suppressSpeciesTap = true
                }
            }
            .updating($swipeTranslation) { value, state, _ in
                guard canHandleSwipe(value) else {
                    state = 0
                    return
                }

                state = min(0, value.translation.width)
            }
            .onEnded { value in
                handleNextSpotSwipe(value, containerWidth: containerWidth)
                scheduleSpeciesTapReset()
            }
    }

    private func scheduleSpeciesTapReset() {
        speciesTapResetTask?.cancel()
        speciesTapResetTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            suppressSpeciesTap = false
        }
    }

    private func handleNextSpotSwipe(_ value: DragGesture.Value, containerWidth: CGFloat) {
        guard canHandleSwipe(value) else {
            return
        }

        let projectedOffset = min(value.translation.width, value.predictedEndTranslation.width)

        guard projectedOffset < -swipeCommitThreshold else {
            return
        }

        let spotID = viewModel.currentSpot?.id
        committedSwipeSpotID = spotID
        committedSwipeOffset = -containerWidth

        Task {
            await viewModel.advanceOrSkipCurrentSpotFromSwipe()
            // Guaranteed reset regardless of how SwiftUI batches @Published changes.
            // Only clear if no newer swipe has overwritten the committed ID.
            if committedSwipeSpotID == spotID {
                committedSwipeSpotID = nil
                committedSwipeOffset = 0
            }
        }
    }

    private var cardOffset: CGFloat {
        if committedSwipeSpotID == viewModel.currentSpot?.id {
            return committedSwipeOffset
        }
        return swipeTranslation
    }

    private var cardOpacity: Double {
        1
    }

    private func nextCardOffset(containerWidth: CGFloat) -> CGFloat {
        let progressOffset = max(-containerWidth, min(0, cardOffset))
        return containerWidth + progressOffset
    }

    private func canHandleSwipe(_ value: DragGesture.Value) -> Bool {
        let horizontal = abs(value.translation.width)
        let vertical = abs(value.translation.height)
        let isLeftSwipe = value.translation.width < 0
        let isClearlyHorizontal = horizontal > (vertical * 1.35)
        let hasEnoughHorizontalTravel = horizontal >= 24

        return isLeftSwipe
            && isClearlyHorizontal
            && hasEnoughHorizontalTravel
            && !viewModel.isSubmittingIdentification
            && !viewModel.isSpotInfoPanelVisible
            && !viewModel.isAdvancing
    }

    private func shouldSuppressSpeciesTap(for value: DragGesture.Value) -> Bool {
        let horizontal = abs(value.translation.width)
        let vertical = abs(value.translation.height)
        let isLeftSwipe = value.translation.width < 0
        let isMostlyHorizontal = horizontal > vertical

        return isLeftSwipe && isMostlyHorizontal && horizontal >= 8
    }

    private var isSwipeTransitionActive: Bool {
        swipeTranslation < -1 || committedSwipeSpotID == viewModel.currentSpot?.id
    }

    private var isSpeciesSelectionEnabled: Bool {
        !(viewModel.isPanelVisible || viewModel.isSpotInfoPanelVisible || viewModel.isAdvancing || suppressSpeciesTap || isSwipeTransitionActive)
    }

    private func backgroundView(height: CGFloat) -> some View {
        ZStack {
            Color("BrandBeige")
            RadialGradient(
                colors: [.clear, .black.opacity(0.12)],
                center: .center,
                startRadius: 50,
                endRadius: height * 0.7
            )
        }
        .ignoresSafeArea()
    }

    private var emptyContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color("BrandGreen"))
                .accessibilityHidden(true)

            Text("identification.empty.title")
                .font(.title2.bold())
                .foregroundStyle(Color("BrandDarkGray"))

            Text("identification.empty.message")
                .foregroundStyle(Color("BrandDarkGray").opacity(0.7))

            Button(String(localized: "identification.empty.button")) {
                Task { await viewModel.loadNextSpot() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("BrandGreen"))
        }
    }

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(Color("BrandGreen"))
                .accessibilityHidden(true)

            Text(message)
                .foregroundStyle(Color("BrandDarkGray").opacity(0.8))
                .multilineTextAlignment(.center)

            Button(String(localized: "common.retry")) {
                Task { await viewModel.loadNextSpot() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("BrandGreen"))
        }
        .padding()
    }
}

struct IdentificationView_Previews: PreviewProvider {
    static var previews: some View {
        IdentificationView(authManager: AuthManager.shared)
    }
}
