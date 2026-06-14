import SwiftUI
import UIKit

struct IdentificationView: View {

    @ObservedObject var authManager: AuthManager
    @StateObject private var viewModel = IdentificationViewModel()
    @GestureState private var swipeTranslation: CGFloat = 0
    @State private var committedSwipeSpotID: Int?
    @State private var committedSwipeOffset: CGFloat = 0
    @State private var isPreviousSpotTransitionActive = false
    @State private var previousSpotTransitionOffset: CGFloat = 0
    @State private var suppressSpeciesTap = false
    @State private var speciesTapResetTask: Task<Void, Never>?
    @State private var isProfileDrawerPresented = false
    @State private var isLeaderboardPresented = false
    @State private var fullscreenVideoURL: URL?
    @State private var isVideoZoomed = false
    var pendingSpotID: Int? = nil
    var onSpotDeepLinkConsumed: () -> Void = {}

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
                .fullScreenCover(
                    isPresented: Binding(
                        get: { fullscreenVideoURL != nil },
                        set: { isPresented in
                            if !isPresented { fullscreenVideoURL = nil }
                        }
                    )
                ) {
                    if let url = fullscreenVideoURL {
                        FullscreenVideoPlayerView(url: url) {
                            fullscreenVideoURL = nil
                        }
                    }
                }
                .task(id: pendingSpotID) {
                    if let spotID = pendingSpotID {
                        await viewModel.loadSpot(byID: spotID)
                        onSpotDeepLinkConsumed()
                    } else {
                        await viewModel.loadInitial()
                    }
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
            spot: viewModel.displayedSpot,
            activePanel: viewModel.activeSpotInfoPanel,
            commentCount: viewModel.displayedCommentCount,
            favoriteCount: viewModel.displayedFavoriteCount,
            isFavorited: viewModel.displayedIsFavorited,
            comments: viewModel.displayedComments,
            commentsOpen: viewModel.displayedCommentsOpen,
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
            },
            onAdvance: {
                if viewModel.isShowingPreviousSpot {
                    viewModel.returnToCurrentSpot()
                } else {
                    Task { await viewModel.advanceOrSkipCurrentSpotFromSwipe() }
                }
            }
        )
    }

    // MARK: - Pager

    private func spotPager(_ spot: Spot, containerWidth: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            if viewModel.isShowingPreviousSpot, let previousEntry = viewModel.previousSpot {
                // Peek of the current spot, sliding back in from the right
                // while the user swipes left to return.
                spotContent(spot, isPreview: true, containerWidth: containerWidth)
                    .offset(x: nextCardOffset(containerWidth: containerWidth))
                    .allowsHitTesting(false)

                spotContent(previousEntry.spot, isPreviousSpot: true, containerWidth: containerWidth)
                    .id("previous-\(previousEntry.spot.id)")
            } else {
                if viewModel.canShowPreviousSpot, let previousEntry = viewModel.previousSpot {
                    // Peek of the previous spot, sliding in from the left.
                    spotContent(previousEntry.spot, isPreview: true, isPreviousSpot: true, containerWidth: containerWidth)
                        .offset(x: previousCardOffset(containerWidth: containerWidth))
                        .allowsHitTesting(false)
                }

                if let nextSpot = viewModel.upcomingSpot, nextSpot.id != spot.id {
                    // Intentionally render the full incoming card for a seamless swipe handoff without pop-in.
                    spotContent(nextSpot, isPreview: true, containerWidth: containerWidth)
                        .offset(x: nextCardOffset(containerWidth: containerWidth))
                        .allowsHitTesting(false)
                }

                spotContent(spot, containerWidth: containerWidth)
                    .id(spot.id)
            }

            if viewModel.isAdvancing {
                ProgressView(String(localized: "identification.loading"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            // Community verdict panel overlay (current spot)
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

            // Read-only community verdict for the previous spot — no countdown,
            // no auto-advance. The icon bar's arrow is the only way back.
            if viewModel.shouldShowPreviousCommunityVerdictPanel {
                CommunityVerdictPanel(
                    panelState: viewModel.previousPanelState,
                    catalogStore: viewModel.catalogStore,
                    countdownRemaining: 0,
                    countdownDuration: viewModel.countdownDuration,
                    hideCountdown: true,
                    onAdvance: {},
                    onClose: {
                        viewModel.hidePreviousCommunityVerdictPanel()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.shouldShowCommunityVerdictPanel)
        .animation(.easeInOut(duration: 0.3), value: viewModel.shouldShowPreviousCommunityVerdictPanel)
    }

    // MARK: - Subviews

    private func spotContent(_ spot: Spot, isPreview: Bool = false, isPreviousSpot: Bool = false, containerWidth: CGFloat) -> some View {
        let selectionEnabled = isPreviousSpot ? isPreviousSpeciesSelectionEnabled : isSpeciesSelectionEnabled
        let highlightedSpeciesID = isPreviousSpot ? viewModel.previousChosenSpeciesID : viewModel.currentChosenSpeciesID

        return VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                VideoPlayerView(
                    url: spot.videoURL,
                    isActive: !isPreview && !viewModel.isAdvancing && !viewModel.isSpotInfoPanelVisible
                        && (isPreviousSpot ? true : !viewModel.isPanelVisible)
                )
                .pinchToZoom(maxScale: 4, isZoomed: isPreview || isPreviousSpot ? .constant(false) : $isVideoZoomed)
                .accessibilityLabel(String(localized: "accessibility.videoPlayer"))

                if !isPreview {
                    Button {
                        fullscreenVideoURL = spot.videoURL
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel(String(localized: "accessibility.fullscreenVideo"))
                }
            }
            .aspectRatio(16/9, contentMode: .fit)

            ScrollView {
                VStack(spacing: 12) {
                    Text("identification.question")
                        .font(.headline)
                        .foregroundStyle(Color("BrandDarkGray"))

                    SpeciesSelectionView(
                        species: viewModel.selectableSpecies(for: spot),
                        catalog: viewModel.catalogStore.species,
                        isDisabled: !selectionEnabled,
                        dimWhenDisabled: highlightedSpeciesID != nil,
                        highlightedSpeciesID: highlightedSpeciesID,
                        onTapHighlighted: {
                            if isPreviousSpot {
                                viewModel.togglePreviousCommunityVerdictPanel()
                            } else {
                                viewModel.toggleCommunityVerdictPanel()
                            }
                        }
                    ) { selected in
                        guard selectionEnabled else { return }
                        Task {
                            await viewModel.submitIdentification(species: selected)
                        }
                    }
                    .allowsHitTesting(selectionEnabled || highlightedSpeciesID != nil)
                    .accessibilityHidden(!selectionEnabled && highlightedSpeciesID == nil)
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
        .onChange(of: spot.id) { _, _ in
            // A new spot always starts unzoomed, so make sure swiping isn't left
            // disabled if the previous spot's video was zoomed when we navigated away.
            if !isPreview && !isPreviousSpot {
                isVideoZoomed = false
            }
        }
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.86), value: swipeTranslation)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.86), value: committedSwipeOffset)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.86), value: previousSpotTransitionOffset)
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

                if viewModel.isShowingPreviousSpot {
                    state = min(0, value.translation.width)
                } else if value.translation.width < 0 {
                    state = value.translation.width
                } else {
                    state = viewModel.canShowPreviousSpot ? value.translation.width : 0
                }
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

        let isLeftSwipe = value.translation.width < 0

        if viewModel.isShowingPreviousSpot {
            guard isLeftSwipe else { return }

            let projectedOffset = min(value.translation.width, value.predictedEndTranslation.width)
            guard projectedOffset < -swipeCommitThreshold else { return }

            isPreviousSpotTransitionActive = true
            previousSpotTransitionOffset = -containerWidth

            Task {
                try? await Task.sleep(for: .milliseconds(220))
                viewModel.returnToCurrentSpot()
                previousSpotTransitionOffset = 0
                isPreviousSpotTransitionActive = false
            }
            return
        }

        if !isLeftSwipe {
            let projectedOffset = max(value.translation.width, value.predictedEndTranslation.width)
            guard projectedOffset > swipeCommitThreshold, viewModel.canShowPreviousSpot else { return }

            isPreviousSpotTransitionActive = true
            previousSpotTransitionOffset = containerWidth

            Task {
                try? await Task.sleep(for: .milliseconds(220))
                viewModel.showPreviousSpot()
                previousSpotTransitionOffset = 0
                isPreviousSpotTransitionActive = false
            }
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
        if isPreviousSpotTransitionActive {
            return previousSpotTransitionOffset
        }
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

    private func previousCardOffset(containerWidth: CGFloat) -> CGFloat {
        let progressOffset = max(0, min(containerWidth, cardOffset))
        return -containerWidth + progressOffset
    }

    private func canHandleSwipe(_ value: DragGesture.Value) -> Bool {
        let horizontal = abs(value.translation.width)
        let vertical = abs(value.translation.height)
        let isLeftSwipe = value.translation.width < 0
        let isRightSwipe = value.translation.width > 0
        let isClearlyHorizontal = horizontal > (vertical * 1.35)
        let hasEnoughHorizontalTravel = horizontal >= 24

        let baseConditions = isClearlyHorizontal
            && hasEnoughHorizontalTravel
            && !viewModel.isSpotInfoPanelVisible
            && !viewModel.isAdvancing
            && !isPreviousSpotTransitionActive
            && !isVideoZoomed
            && committedSwipeSpotID == nil

        if viewModel.isShowingPreviousSpot {
            return isLeftSwipe && baseConditions
        }

        let directionAllowed = isLeftSwipe || (isRightSwipe && viewModel.canShowPreviousSpot)

        return directionAllowed
            && baseConditions
            && !viewModel.isSubmittingIdentification
    }

    private func shouldSuppressSpeciesTap(for value: DragGesture.Value) -> Bool {
        let horizontal = abs(value.translation.width)
        let vertical = abs(value.translation.height)
        let isMostlyHorizontal = horizontal > vertical

        return isMostlyHorizontal && horizontal >= 8
    }

    private var isSwipeTransitionActive: Bool {
        swipeTranslation != 0 || committedSwipeSpotID == viewModel.currentSpot?.id || isPreviousSpotTransitionActive
    }

    private var isSpeciesSelectionEnabled: Bool {
        !(viewModel.isPanelVisible || viewModel.isSpotInfoPanelVisible || viewModel.isAdvancing || suppressSpeciesTap || isSwipeTransitionActive)
    }

    private var isPreviousSpeciesSelectionEnabled: Bool {
        viewModel.isPreviousSpotEditable
            && !viewModel.isSubmittingPreviousIdentification
            && !viewModel.isSpotInfoPanelVisible
            && !suppressSpeciesTap
            && !isSwipeTransitionActive
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
