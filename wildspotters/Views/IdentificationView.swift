import SwiftUI
import UIKit

struct IdentificationView: View {

    @ObservedObject var authManager: AuthManager
    @StateObject private var viewModel = IdentificationViewModel()
    @GestureState private var swipeTranslation: CGFloat = 0
    @State private var committedSwipeSpotID: Int?

    private let swipeCommitThreshold: CGFloat = 48
    private let swipeTravelCap: CGFloat = 72

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
                        spotPager(spot)
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
                .task {
                    await viewModel.loadInitial()
                }
                .onDisappear {
                    viewModel.tearDown()
                }
            }
        }
    }

    // MARK: - Pager

    private func spotPager(_ spot: Spot) -> some View {
        ZStack(alignment: .bottom) {
            spotContent(spot)
                .id(spot.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

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
        .animation(.spring(duration: 0.25, bounce: 0), value: viewModel.currentSpot?.id)
    }

    // MARK: - Subviews

    private func spotContent(_ spot: Spot) -> some View {
        VStack(spacing: 0) {
            VideoPlayerView(
                url: spot.videoURL,
                isActive: !viewModel.isPanelVisible && !viewModel.isAdvancing
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
                        isDisabled: viewModel.isPanelVisible || viewModel.isAdvancing
                    ) { selected in
                        Task {
                            await viewModel.submitIdentification(species: selected)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .background(Color("BrandBeige"))
        .offset(x: cardOffset)
        .opacity(cardOpacity)
        .contentShape(Rectangle())
        .highPriorityGesture(nextSpotSwipeGesture)
        .allowsHitTesting(!viewModel.isAdvancing)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.86), value: swipeTranslation)
    }

    private var nextSpotSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .updating($swipeTranslation) { value, state, _ in
                guard canHandleSwipe(value) else {
                    state = 0
                    return
                }

                state = max(-swipeTravelCap, min(0, value.translation.width))
            }
            .onEnded(handleNextSpotSwipe)
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task {
            await viewModel.skipCurrentSpot()
            // Guaranteed reset regardless of how SwiftUI batches @Published changes.
            // Only clear if no newer swipe has overwritten the committed ID.
            if committedSwipeSpotID == spotID {
                committedSwipeSpotID = nil
            }
        }
    }

    private var cardOffset: CGFloat {
        if committedSwipeSpotID == viewModel.currentSpot?.id {
            return -swipeTravelCap
        }
        return swipeTranslation
    }

    private var cardOpacity: Double {
        let progress = min(abs(cardOffset) / swipeTravelCap, 1)
        return 1 - (Double(progress) * 0.08)
    }

    private func canHandleSwipe(_ value: DragGesture.Value) -> Bool {
        let isLeftSwipe = value.translation.width < 0
        let isMostlyHorizontal = abs(value.translation.width) > abs(value.translation.height)
        return isLeftSwipe && isMostlyHorizontal && !viewModel.isPanelVisible && !viewModel.isAdvancing
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
