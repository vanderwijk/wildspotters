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

    private let swipeCommitThreshold: CGFloat = 72

    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                ZStack {
                    backgroundView(height: geometry.size.height)

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
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color("BrandBeige").opacity(0.9), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 44)
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            authManager.logout()
                        } label: {
                            Image("LogoutIcon")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    footerBar
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

    // MARK: - Footer

    private var footerBar: some View {
        VStack(spacing: 0) {
            Image("FooterGrass")
                .resizable()
                .scaledToFill()
                .frame(height: 50)
                .clipped()
                .allowsHitTesting(false)

            Color("BrandDarkGreen")
                .frame(height: 30)
                .background(Color("BrandDarkGreen").ignoresSafeArea(edges: .bottom))
        }
    }

    // MARK: - Pager

    private func spotPager(_ spot: Spot, containerWidth: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            if let nextSpot = viewModel.upcomingSpot, nextSpot.id != spot.id {
                // Intentionally render the full incoming card for a seamless swipe handoff without pop-in.
                spotContent(nextSpot, isPreview: true)
                    .offset(x: nextCardOffset(containerWidth: containerWidth))
                    .allowsHitTesting(false)
            }

            spotContent(spot)
                .id(spot.id)

            if viewModel.isAdvancing {
                ProgressView(String(localized: "identification.loading"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            // Community verdict panel overlay
            if viewModel.isPanelVisible {
                CommunityVerdictPanel(
                    panelState: viewModel.panelState,
                    catalogStore: viewModel.catalogStore,
                    countdownRemaining: viewModel.countdownRemaining,
                    countdownDuration: viewModel.countdownDuration,
                    onAdvance: {
                        Task { await viewModel.advanceToNextSpot() }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isPanelVisible)
    }

    // MARK: - Subviews

    private func spotContent(_ spot: Spot, isPreview: Bool = false) -> some View {
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
                        isDisabled: false,
                        dimWhenDisabled: false,
                    ) { selected in
                        guard isSpeciesSelectionEnabled else { return }
                        Task {
                            await viewModel.submitIdentification(species: selected)
                        }
                    }
                    .allowsHitTesting(isSpeciesSelectionEnabled)
                }
                .padding(.vertical, 16)
            }
            .scrollDisabled(isSwipeTransitionActive)
        }
        .background(Color("BrandBeige"))
        .offset(x: isPreview ? 0 : cardOffset)
        .opacity(isPreview ? 1 : cardOpacity)
        .contentShape(Rectangle())
        .simultaneousGesture(nextSpotSwipeGesture)
        .allowsHitTesting(!viewModel.isAdvancing)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.86), value: swipeTranslation)
    }

    private var nextSpotSwipeGesture: some Gesture {
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
                handleNextSpotSwipe(value)
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

    private func handleNextSpotSwipe(_ value: DragGesture.Value) {
        guard canHandleSwipe(value) else {
            return
        }

        let projectedOffset = min(value.translation.width, value.predictedEndTranslation.width)

        guard projectedOffset < -swipeCommitThreshold else {
            return
        }

        let spotID = viewModel.currentSpot?.id
        committedSwipeSpotID = spotID
        committedSwipeOffset = min(0, value.translation.width)

        Task {
            await viewModel.skipCurrentSpot()
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
            && !viewModel.isPanelVisible
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
        !(viewModel.isPanelVisible || viewModel.isAdvancing || suppressSpeciesTap || isSwipeTransitionActive)
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
