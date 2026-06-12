import Combine
import UIKit
import OSLog

@MainActor
final class IdentificationViewModel: ObservableObject {

    enum PanelState: Equatable {
        case hidden
        case submitting(Species)
        case showing(IdentificationPanel)

        static func == (lhs: PanelState, rhs: PanelState) -> Bool {
            switch (lhs, rhs) {
            case (.hidden, .hidden):
                return true
            case (.submitting(let a), .submitting(let b)):
                return a.id == b.id
            case (.showing(let a), .showing(let b)):
                return a.selectedSpecies.id == b.selectedSpecies.id
            default:
                return false
            }
        }
    }

    enum NextSpotTransitionResult {
        case advanced
        case emptyQueue
        case failed
    }

    enum SpotInfoPanel: Equatable {
        case comments
        case location
        case likes
    }

    @Published private(set) var currentSpot: Spot?
    @Published private(set) var upcomingSpot: Spot?
    @Published private(set) var isLoading = false
    @Published private(set) var isEmpty = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var panelState: PanelState = .hidden
    @Published private(set) var countdownRemaining: Int = 0
    @Published private(set) var isAdvancing = false
    @Published var activeSpotInfoPanel: SpotInfoPanel?
    @Published var commentDraft = ""
    @Published private(set) var spotComments: [SpotComment] = []
    @Published private(set) var commentCount = 0
    @Published private(set) var commentsOpen = true
    @Published private(set) var isLoadingComments = false
    @Published private(set) var isSubmittingComment = false
    @Published private(set) var isUpdatingFavorite = false
    @Published private(set) var favoriteCount = 0
    @Published private(set) var isFavorited = false
    @Published private(set) var spotInfoMessage: String?
    @Published private(set) var spotInfoError: String?
    @Published private(set) var isCommunityVerdictPanelHidden = false

    let catalogStore = CatalogStore.shared
    private let apiClient = APIClient.shared
    private let logger = Logger(subsystem: "nl.wildspotters.app", category: "Identification")
    private var countdownTask: Task<Void, Never>?
    private var preloadTask: Task<Void, Never>?
    private var preloadedSpot: Spot?
    private var recentSpotIDs: [Int] = []
    private static let countdownDuration = 10
    private static let skipTermID = 74
    private static let exclusionHistoryLimit = 12

    var countdownDuration: Int { Self.countdownDuration }

    var isPanelVisible: Bool {
        switch panelState {
        case .submitting, .showing:
            return true
        default:
            return false
        }
    }

    var isSubmittingIdentification: Bool {
        if case .submitting = panelState { return true }
        return false
    }

    var hasAnsweredCurrentSpot: Bool {
        if case .showing = panelState { return true }
        return false
    }

    var shouldShowCommunityVerdictPanel: Bool {
        isPanelVisible && !isSpotInfoPanelVisible && !isCommunityVerdictPanelHidden
    }

    var isSpotInfoPanelVisible: Bool {
        activeSpotInfoPanel != nil
    }

    func selectableSpecies(for spot: Spot) -> [Species] {
        spot.speciesOptions.filter { $0.id != Self.skipTermID }
    }

    // MARK: - Loading

    func loadInitial() async {
        async let catalogRefresh: () = catalogStore.refresh()
        async let spotsLoad: () = loadFirstSpot()
        _ = await (catalogRefresh, spotsLoad)
    }

    private func loadFirstSpot() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if let spot = try await apiClient.fetchNextSpot() {
                showSpot(spot)
                preloadNextSpot()
            } else {
                showEmptyState()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Called from empty/error states to retry loading.
    func loadNextSpot() async {
        errorMessage = nil
        isEmpty = false
        isLoading = true
        defer { isLoading = false }

        let excludeIDs = nextSpotExclusionIDs()
        do {
            if let spot = try await apiClient.fetchNextSpot(excluding: excludeIDs) {
                showSpot(spot)
                preloadNextSpot()
            } else {
                showEmptyState()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetches the next spot in the background and keeps it off-screen until promoted.
    private func preloadNextSpot() {
        preloadTask?.cancel()
        preloadTask = Task {
            let excludeIDs = nextSpotExclusionIDs()
            if let spot = try? await apiClient.fetchNextSpot(excluding: excludeIDs) {
                guard !Task.isCancelled else { return }
                setPreloadedSpot(spot)
            }
        }
    }

    private func nextSpotExclusionIDs() -> [Int] {
        let preloadedSpotIDs = preloadedSpot.map { [$0.id] } ?? []
        return Array((recentSpotIDs + preloadedSpotIDs).suffix(Self.exclusionHistoryLimit))
    }

    private func setPreloadedSpot(_ spot: Spot?) {
        guard preloadedSpot?.id != spot?.id else { return }

        if let previousSpot = preloadedSpot {
            PlayerCache.shared.releasePreparedPlayer(for: previousSpot.videoURL)
        }

        preloadedSpot = spot
        upcomingSpot = spot

        if let spot {
            PlayerCache.shared.preparePlayer(for: spot.videoURL)
        }
    }

    private func clearPreloadedSpot() {
        setPreloadedSpot(nil)
    }

    private func consumePreloadedSpot() -> Spot? {
        guard let spot = preloadedSpot else { return nil }
        preloadedSpot = nil
        upcomingSpot = nil
        PlayerCache.shared.consumePreparedPlayer(for: spot.videoURL)
        return spot
    }

    private func showSpot(_ spot: Spot) {
        currentSpot = spot
        appendRecentSpotID(spot.id)
        resetSpotInfoState(for: spot)
        isCommunityVerdictPanelHidden = false
        isEmpty = false
        errorMessage = nil
    }

    private func appendRecentSpotID(_ spotID: Int) {
        if recentSpotIDs.last != spotID {
            recentSpotIDs.append(spotID)
        }
        if recentSpotIDs.count > Self.exclusionHistoryLimit {
            recentSpotIDs.removeFirst(recentSpotIDs.count - Self.exclusionHistoryLimit)
        }
    }

    private func showEmptyState() {
        currentSpot = nil
        resetSpotInfoState(for: nil)
        isCommunityVerdictPanelHidden = false
        clearPreloadedSpot()
        isEmpty = true
    }

    private func moveToNextSpot() async -> NextSpotTransitionResult {
        isAdvancing = true
        defer { isAdvancing = false }

        if let preloadedSpot = consumePreloadedSpot() {
            showSpot(preloadedSpot)
            preloadNextSpot()
            return .advanced
        }

        do {
            if let spot = try await apiClient.fetchNextSpot(excluding: nextSpotExclusionIDs()) {
                showSpot(spot)
                preloadNextSpot()
                return .advanced
            } else {
                showEmptyState()
                return .emptyQueue
            }
        } catch {
            errorMessage = error.localizedDescription
            return .failed
        }
    }

    // MARK: - Skip (swipe forward)

    /// Called when user swipes left. Advances to the next spot with a
    /// slide transition. Promote + index change happen together.
    func skipCurrentSpot() async {
        guard let spot = currentSpot, !isAdvancing else { return }

        let transitionResult = await moveToNextSpot()
        guard transitionResult != .failed else { return }

        Task {
            await submitSkip(for: spot)
        }
    }

    func advanceOrSkipCurrentSpotFromSwipe() async {
        if hasAnsweredCurrentSpot {
            await advanceToNextSpot()
        } else {
            await skipCurrentSpot()
        }
    }

    // MARK: - Identification (species tap)

    func submitIdentification(species: Species) async {
        guard let spot = currentSpot, !isAdvancing else { return }

        closeSpotInfoPanel()
        isCommunityVerdictPanelHidden = false
        panelState = .submitting(species)
        let identification = Identification(spotID: spot.id, speciesID: species.id)

        do {
            let panel = try await apiClient.submitIdentification(identification)
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            if let panel {
                panelState = .showing(panel)
                startCountdown()
            } else {
                await advanceToNextSpot()
            }
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            panelState = .hidden
            errorMessage = error.localizedDescription
        }
    }

    func advanceToNextSpot() async {
        guard !isAdvancing else { return }
        cancelCountdown()
        panelState = .hidden
        isCommunityVerdictPanelHidden = false
        closeSpotInfoPanel()
        _ = await moveToNextSpot()
    }

    func hideCommunityVerdictPanel() {
        guard isPanelVisible else { return }
        cancelCountdown()
        isCommunityVerdictPanelHidden = true
    }

    // MARK: - Spot info

    func toggleSpotInfoPanel(_ panel: SpotInfoPanel) async {
        guard currentSpot != nil, !isSubmittingIdentification, !isAdvancing else { return }

        if panel == .likes {
            closeSpotInfoPanel()
            await toggleFavorite()
            return
        }

        if activeSpotInfoPanel == panel {
            closeSpotInfoPanel()
            return
        }

        if hasAnsweredCurrentSpot {
            cancelCountdown()
        }

        activeSpotInfoPanel = panel
        spotInfoMessage = nil
        spotInfoError = nil

        if panel == .comments {
            await loadCommentsIfNeeded()
        }
    }

    func closeSpotInfoPanel() {
        let hadSpotInfoPanel = activeSpotInfoPanel != nil
        activeSpotInfoPanel = nil
        spotInfoMessage = nil
        spotInfoError = nil

        if hadSpotInfoPanel && hasAnsweredCurrentSpot && !isCommunityVerdictPanelHidden {
            startCountdown()
        }
    }

    func refreshComments() async {
        await loadComments(force: true)
    }

    func submitComment() async {
        guard let spot = currentSpot, !isSubmittingComment else { return }

        let content = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSubmittingComment = true
        spotInfoMessage = nil
        spotInfoError = nil
        defer { isSubmittingComment = false }

        do {
            let response = try await apiClient.submitComment(content, for: spot.id)
            commentsOpen = response.commentsOpen
            commentCount = response.commentCount
            commentDraft = ""

            if response.comment.isPending {
                spotInfoMessage = String(localized: "spotInfo.comments.pending")
            } else {
                spotComments.append(response.comment)
                spotInfoMessage = String(localized: "spotInfo.comments.posted")
            }

            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            spotInfoError = error.localizedDescription
        }
    }

    func toggleFavorite() async {
        guard let spot = currentSpot, !isUpdatingFavorite else { return }

        let desiredState = !isFavorited
        isUpdatingFavorite = true
        spotInfoMessage = nil
        spotInfoError = nil
        defer { isUpdatingFavorite = false }

        do {
            let response = try await apiClient.setFavorite(desiredState, for: spot.id)
            isFavorited = response.isFavorited
            favoriteCount = response.favoriteCount
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            spotInfoError = error.localizedDescription
        }
    }

    private func loadCommentsIfNeeded() async {
        guard spotComments.isEmpty else { return }
        await loadComments(force: false)
    }

    private func loadComments(force: Bool) async {
        guard let spot = currentSpot, !isLoadingComments else { return }
        guard force || spotComments.isEmpty else { return }

        isLoadingComments = true
        spotInfoError = nil
        defer { isLoadingComments = false }

        do {
            let response = try await apiClient.fetchComments(for: spot.id)
            guard currentSpot?.id == spot.id else { return }
            spotComments = response.comments
            commentCount = response.commentCount
            commentsOpen = response.commentsOpen
        } catch {
            spotInfoError = error.localizedDescription
        }
    }

    private func resetSpotInfoState(for spot: Spot?) {
        activeSpotInfoPanel = nil
        commentDraft = ""
        spotComments = []
        commentCount = spot?.commentCount ?? 0
        commentsOpen = true
        isLoadingComments = false
        isSubmittingComment = false
        isUpdatingFavorite = false
        favoriteCount = spot?.favoriteCount ?? 0
        isFavorited = spot?.isFavorited ?? false
        spotInfoMessage = nil
        spotInfoError = nil
    }

    // MARK: - Countdown

    private func startCountdown() {
        cancelCountdown()
        countdownRemaining = Self.countdownDuration

        countdownTask = Task {
            for tick in stride(from: Self.countdownDuration - 1, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                countdownRemaining = tick
            }
            guard !Task.isCancelled else { return }
            countdownTask = nil
            await advanceToNextSpot()
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownRemaining = 0
    }

    func tearDown() {
        cancelCountdown()
        preloadTask?.cancel()
        preloadTask = nil
        clearPreloadedSpot()
    }

    private func submitSkip(for spot: Spot) async {
        let skip = Identification(spotID: spot.id, speciesID: Self.skipTermID)
        do {
            _ = try await apiClient.submitIdentification(skip)
        } catch {
            logger.error("Skip submission failed for spot \(spot.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    deinit {
        countdownTask?.cancel()
        preloadTask?.cancel()
    }
}
