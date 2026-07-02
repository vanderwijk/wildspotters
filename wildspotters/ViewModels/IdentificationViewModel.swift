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

    /// What happened on a spot before the user navigated away from it.
    /// Identifications (`.identified`) are final and can never be revised;
    /// only a skip can later be overwritten by a real identification.
    enum PreviousIdentificationOutcome {
        case skip
        case identified(panel: IdentificationPanel?, chosenSpeciesID: Int)
    }

    /// Single-level "back" buffer holding the spot the user just navigated
    /// away from, including a snapshot of its comments/likes so the
    /// previous-spot screen needs no refetch. Comments/likes remain live and
    /// editable from this snapshot.
    struct PreviousSpotEntry {
        let spot: Spot
        var comments: [SpotComment]
        var commentCount: Int
        var commentsOpen: Bool
        var favoriteCount: Int
        var isFavorited: Bool
        var identificationOutcome: PreviousIdentificationOutcome
    }

    @Published private(set) var currentSpot: Spot?
    @Published private(set) var upcomingSpot: Spot?
    @Published private(set) var previousSpot: PreviousSpotEntry?
    @Published private(set) var isShowingPreviousSpot = false
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
    @Published private(set) var isPreviousCommunityVerdictPanelHidden = false
    @Published private(set) var isSubmittingPreviousIdentification = false

    let catalogStore = CatalogStore.shared
    private let apiClient = APIClient.shared
    private let pendingSkipStore = PendingSkipStore.shared
    private let logger = Logger(subsystem: "nl.wildspotters.app", category: "Identification")
    private var countdownTask: Task<Void, Never>?
    private var preloadTask: Task<Void, Never>?
    private var pendingSkipFlushTask: Task<Void, Never>?
    private var preloadedSpot: Spot?
    private var recentSpotIDs: [Int] = []
    private static let countdownDuration = 10
    private static let skipTermID = 74
    private static let exclusionHistoryLimit = 12
    private static let skipSubmissionMaxAttempts = 3
    private static let skipSubmissionRetryBaseDelay: Double = 2

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
        !isShowingPreviousSpot && isPanelVisible && !isSpotInfoPanelVisible && !isCommunityVerdictPanelHidden
    }

    var isSpotInfoPanelVisible: Bool {
        activeSpotInfoPanel != nil
    }

    /// True when video playback for the spot currently on screen should be
    /// paused (an overlay panel covers it, or we're mid-transition).
    var isVideoPlaybackBlocked: Bool {
        if case .submitting = panelState {
            return true
        }

        return shouldShowCommunityVerdictPanel
    }

    // MARK: - Previous-spot buffer

    /// True when there is a buffered previous spot the user can swipe back to.
    var canShowPreviousSpot: Bool {
        previousSpot != nil && !isShowingPreviousSpot
    }

    /// The spot whose data (comments/likes/etc.) the footer and content
    /// should currently reflect.
    var displayedSpot: Spot? {
        isShowingPreviousSpot ? previousSpot?.spot : currentSpot
    }

    var displayedComments: [SpotComment] {
        isShowingPreviousSpot ? (previousSpot?.comments ?? []) : spotComments
    }

    var displayedCommentCount: Int {
        isShowingPreviousSpot ? (previousSpot?.commentCount ?? 0) : commentCount
    }

    var displayedCommentsOpen: Bool {
        isShowingPreviousSpot ? (previousSpot?.commentsOpen ?? true) : commentsOpen
    }

    var displayedFavoriteCount: Int {
        isShowingPreviousSpot ? (previousSpot?.favoriteCount ?? 0) : favoriteCount
    }

    var displayedIsFavorited: Bool {
        isShowingPreviousSpot ? (previousSpot?.isFavorited ?? false) : isFavorited
    }

    /// Identifications are final. The previous-spot screen is only editable
    /// when the buffered action was a skip (which may still be overwritten).
    var isPreviousSpotEditable: Bool {
        guard isShowingPreviousSpot else { return false }
        if case .skip = previousSpot?.identificationOutcome { return true }
        return false
    }

    /// The species the user previously chose, used to highlight it (read-only)
    /// in the species grid on the previous-spot screen.
    var previousChosenSpeciesID: Int? {
        if case .identified(_, let chosenSpeciesID) = previousSpot?.identificationOutcome {
            return chosenSpeciesID
        }
        return nil
    }

    /// The species the user just chose for the current spot, used to highlight
    /// it in the species grid the instant they tap it — while the submission
    /// is in flight, while the community verdict panel is showing, and after
    /// it's been minimized.
    var currentChosenSpeciesID: Int? {
        switch panelState {
        case .submitting(let species):
            return species.id
        case .showing(let panel):
            return panel.selectedSpecies.id
        case .hidden:
            return nil
        }
    }

    var previousPanelState: PanelState {
        if case .identified(let panel, _) = previousSpot?.identificationOutcome, let panel {
            return .showing(panel)
        }
        return .hidden
    }

    /// Read-only community verdict panel for the previous spot. Never shows a
    /// countdown / auto-advance — the icon bar's existing arrow is the only
    /// way back to the current spot.
    var shouldShowPreviousCommunityVerdictPanel: Bool {
        guard isShowingPreviousSpot, !isSpotInfoPanelVisible, !isPreviousCommunityVerdictPanelHidden else { return false }
        if case .identified(let panel, _) = previousSpot?.identificationOutcome {
            return panel != nil
        }
        return false
    }

    func selectableSpecies(for spot: Spot) -> [Species] {
        spot.speciesOptions.filter { $0.id != Self.skipTermID }
    }

    // MARK: - Loading

    func loadInitial() async {
        async let catalogRefresh: () = catalogStore.refresh()
        async let spotsLoad: () = loadFirstSpot()
        async let skipFlush: () = flushPendingSkips()
        _ = await (catalogRefresh, spotsLoad, skipFlush)
    }

    func loadSpot(byID spotID: Int) async {
        isLoading = true
        defer { isLoading = false }

        isShowingPreviousSpot = false
        previousSpot = nil
        errorMessage = nil
        isEmpty = false

        async let catalogRefresh: () = catalogStore.refresh()
        async let skipFlush: () = flushPendingSkips()

        do {
            if let spot = try await apiClient.fetchSpot(id: spotID) {
                _ = await (catalogRefresh, skipFlush)
                showSpot(spot)
                preloadNextSpot()
            } else {
                _ = await (catalogRefresh, skipFlush)
                showEmptyState()
            }
        } catch {
            _ = await (catalogRefresh, skipFlush)
            errorMessage = error.localizedDescription
        }
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
        applyExistingIdentification(from: spot)
        isEmpty = false
        errorMessage = nil
    }

    /// Restore highlight / verdict state when reopening a spot the user already identified.
    private func applyExistingIdentification(from spot: Spot) {
        guard let identification = spot.userIdentification, let panel = identification.panel else {
            panelState = .hidden
            isCommunityVerdictPanelHidden = false
            return
        }

        panelState = .showing(panel)
        isCommunityVerdictPanelHidden = true
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

        isShowingPreviousSpot = false
        // Collapsed by default: don't auto-pop the verdict panel for the spot
        // we're leaving when the user later swipes back to it.
        isPreviousCommunityVerdictPanelHidden = true

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

    /// Moves the spot we're leaving into the single-level "back" buffer,
    /// reusing its already-loaded comments/likes/identification result.
    /// Keeps its video player warm in `PlayerCache` (no release) so swiping
    /// back doesn't reload it, and releases whatever was buffered before.
    private func captureCurrentSpotAsPrevious() {
        guard let spot = currentSpot else { return }

        let outcome: PreviousIdentificationOutcome
        if case .showing(let panel) = panelState {
            outcome = .identified(panel: panel, chosenSpeciesID: panel.selectedSpecies.id)
        } else {
            outcome = .skip
        }

        if let oldPrevious = previousSpot {
            PlayerCache.shared.releasePlayer(for: oldPrevious.spot.videoURL)
        }

        // Retain an extra reference so the player survives this spot's
        // VideoPlayerView being dismantled when the next spot is shown.
        _ = PlayerCache.shared.retainPlayer(for: spot.videoURL)

        previousSpot = PreviousSpotEntry(
            spot: spot,
            comments: spotComments,
            commentCount: commentCount,
            commentsOpen: commentsOpen,
            favoriteCount: favoriteCount,
            isFavorited: isFavorited,
            identificationOutcome: outcome
        )
    }

    // MARK: - Previous-spot navigation

    /// Swipe right (or tap the arrow on the previous screen's mirror) to peek
    /// at the buffered previous spot. Pure UI toggle: no fetch, `currentSpot`
    /// is untouched.
    func showPreviousSpot() {
        guard previousSpot != nil, !isShowingPreviousSpot, !isAdvancing else { return }

        if hasAnsweredCurrentSpot {
            cancelCountdown()
        }
        closeSpotInfoPanel()
        isShowingPreviousSpot = true
    }

    /// Returns from the previous-spot screen back to the current spot.
    func returnToCurrentSpot() {
        guard isShowingPreviousSpot else { return }

        closeSpotInfoPanel()
        isShowingPreviousSpot = false

        if hasAnsweredCurrentSpot && !isCommunityVerdictPanelHidden {
            startCountdown()
        }
    }

    func hidePreviousCommunityVerdictPanel() {
        guard shouldShowPreviousCommunityVerdictPanel else { return }
        isPreviousCommunityVerdictPanelHidden = true
    }

    /// Toggles the read-only community verdict panel for the previous spot,
    /// e.g. when the user taps their already-chosen species tile to check
    /// what the community thought again.
    func togglePreviousCommunityVerdictPanel() {
        guard isShowingPreviousSpot, !isSpotInfoPanelVisible else { return }
        guard case .identified(let panel, _) = previousSpot?.identificationOutcome, panel != nil else { return }
        isPreviousCommunityVerdictPanelHidden.toggle()
    }

    // MARK: - Skip (swipe forward)

    /// Called when user swipes left. Advances to the next spot with a
    /// slide transition. Promote + index change happen together.
    func skipCurrentSpot() async {
        guard let spot = currentSpot, !isAdvancing else { return }

        captureCurrentSpotAsPrevious()
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
        if isShowingPreviousSpot {
            await submitIdentificationForPreviousSpot(species: species)
            return
        }

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

    /// Overwrites a previously-skipped spot with a real identification.
    /// Once this succeeds the result becomes final, exactly like the current
    /// spot's identification — no further changes are possible.
    private func submitIdentificationForPreviousSpot(species: Species) async {
        guard isPreviousSpotEditable, let entry = previousSpot, !isSubmittingPreviousIdentification else { return }

        isSubmittingPreviousIdentification = true
        defer { isSubmittingPreviousIdentification = false }

        let identification = Identification(spotID: entry.spot.id, speciesID: species.id)

        do {
            let panel = try await apiClient.submitIdentification(identification)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            previousSpot?.identificationOutcome = .identified(panel: panel, chosenSpeciesID: species.id)
            isPreviousCommunityVerdictPanelHidden = false
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            spotInfoError = error.localizedDescription
        }
    }

    func advanceToNextSpot() async {
        guard !isAdvancing else { return }
        captureCurrentSpotAsPrevious()
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

    /// Toggles the community verdict panel for the current spot, e.g. when
    /// the user taps their already-chosen species tile after minimizing it.
    func toggleCommunityVerdictPanel() {
        guard !isShowingPreviousSpot, isPanelVisible, !isSpotInfoPanelVisible else { return }

        if isCommunityVerdictPanelHidden {
            isCommunityVerdictPanelHidden = false
            if hasAnsweredCurrentSpot {
                startCountdown()
            }
        } else {
            hideCommunityVerdictPanel()
        }
    }

    // MARK: - Spot info

    func toggleSpotInfoPanel(_ panel: SpotInfoPanel) async {
        guard displayedSpot != nil, !isSubmittingIdentification, !isAdvancing else { return }

        if panel == .likes {
            closeSpotInfoPanel()
            await toggleFavorite()
            return
        }

        if activeSpotInfoPanel == panel {
            closeSpotInfoPanel()
            return
        }

        if !isShowingPreviousSpot && hasAnsweredCurrentSpot {
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

        if !isShowingPreviousSpot && hadSpotInfoPanel && hasAnsweredCurrentSpot && !isCommunityVerdictPanelHidden {
            startCountdown()
        }
    }

    func refreshComments() async {
        await loadComments(force: true)
    }

    func submitComment() async {
        guard let spot = displayedSpot, !isSubmittingComment else { return }

        let content = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSubmittingComment = true
        spotInfoMessage = nil
        spotInfoError = nil
        defer { isSubmittingComment = false }

        do {
            let response = try await apiClient.submitComment(content, for: spot.id)

            if isShowingPreviousSpot {
                previousSpot?.commentsOpen = response.commentsOpen
                previousSpot?.commentCount = response.commentCount
            } else {
                commentsOpen = response.commentsOpen
                commentCount = response.commentCount
            }
            commentDraft = ""

            if response.comment.isPending {
                spotInfoMessage = String(localized: "spotInfo.comments.pending")
            } else {
                if isShowingPreviousSpot {
                    previousSpot?.comments.append(response.comment)
                } else {
                    spotComments.append(response.comment)
                }
                spotInfoMessage = String(localized: "spotInfo.comments.posted")
            }

            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            spotInfoError = error.localizedDescription
        }
    }

    func toggleFavorite() async {
        guard let spot = displayedSpot, !isUpdatingFavorite else { return }

        let desiredState = !displayedIsFavorited
        isUpdatingFavorite = true
        spotInfoMessage = nil
        spotInfoError = nil
        defer { isUpdatingFavorite = false }

        do {
            let response = try await apiClient.setFavorite(desiredState, for: spot.id)

            if isShowingPreviousSpot {
                previousSpot?.isFavorited = response.isFavorited
                previousSpot?.favoriteCount = response.favoriteCount
            } else {
                isFavorited = response.isFavorited
                favoriteCount = response.favoriteCount
            }

            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            spotInfoError = error.localizedDescription
        }
    }

    private func loadCommentsIfNeeded() async {
        let alreadyLoaded = isShowingPreviousSpot ? !(previousSpot?.comments.isEmpty ?? true) : !spotComments.isEmpty
        guard !alreadyLoaded else { return }
        await loadComments(force: false)
    }

    private func loadComments(force: Bool) async {
        guard let spot = displayedSpot, !isLoadingComments else { return }

        let isEmptyCurrently = isShowingPreviousSpot ? (previousSpot?.comments.isEmpty ?? true) : spotComments.isEmpty
        guard force || isEmptyCurrently else { return }

        isLoadingComments = true
        spotInfoError = nil
        defer { isLoadingComments = false }

        do {
            let response = try await apiClient.fetchComments(for: spot.id)
            guard displayedSpot?.id == spot.id else { return }

            if isShowingPreviousSpot {
                previousSpot?.comments = response.comments
                previousSpot?.commentCount = response.commentCount
                previousSpot?.commentsOpen = response.commentsOpen
            } else {
                spotComments = response.comments
                commentCount = response.commentCount
                commentsOpen = response.commentsOpen
            }
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
        pendingSkipFlushTask?.cancel()
        pendingSkipFlushTask = nil
        clearPreloadedSpot()

        if let previousSpot {
            PlayerCache.shared.releasePlayer(for: previousSpot.spot.videoURL)
        }
        previousSpot = nil
    }

    private func submitSkip(for spot: Spot) async {
        await submitSkip(forSpotID: spot.id)
    }

    private func submitSkip(forSpotID spotID: Int) async {
        let skip = Identification(spotID: spotID, speciesID: Self.skipTermID)

        for attempt in 1...Self.skipSubmissionMaxAttempts {
            do {
                _ = try await apiClient.submitIdentification(skip)
                pendingSkipStore.remove(spotID)
                if attempt > 1 {
                    logger.info("Skip submission succeeded for spot \(spotID, privacy: .public) on attempt \(attempt, privacy: .public)")
                }
                return
            } catch is CancellationError {
                return
            } catch {
                logger.error("Skip submission failed for spot \(spotID, privacy: .public) (attempt \(attempt, privacy: .public)/\(Self.skipSubmissionMaxAttempts, privacy: .public)): \(error.localizedDescription, privacy: .public)")

                guard attempt < Self.skipSubmissionMaxAttempts else { break }

                let delay = Self.skipSubmissionRetryBaseDelay * pow(2, Double(attempt - 1))
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    return
                }
            }
        }

        pendingSkipStore.enqueue(spotID)
        schedulePendingSkipFlush()
    }

    private func flushPendingSkips() async {
        let spotIDs = pendingSkipStore.pendingSpotIDs()
        guard !spotIDs.isEmpty else { return }

        for spotID in spotIDs {
            guard !Task.isCancelled else { return }
            await submitSkip(forSpotID: spotID)
        }
    }

    private func schedulePendingSkipFlush() {
        pendingSkipFlushTask?.cancel()
        pendingSkipFlushTask = Task {
            let retryDelays: [Double] = [30, 60, 120, 300]

            for delay in retryDelays {
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    return
                }

                guard !Task.isCancelled else { return }
                await flushPendingSkips()

                if pendingSkipStore.pendingSpotIDs().isEmpty {
                    return
                }
            }
        }
    }

    deinit {
        countdownTask?.cancel()
        preloadTask?.cancel()
        pendingSkipFlushTask?.cancel()
    }
}
