import UIKit
import Combine

@MainActor
final class IdentificationViewModel: ObservableObject {

    enum PanelState: Equatable {
        case hidden
        case submitting(Species)
        case showing(IdentificationPanel)
        case loadingNext

        static func == (lhs: PanelState, rhs: PanelState) -> Bool {
            switch (lhs, rhs) {
            case (.hidden, .hidden), (.loadingNext, .loadingNext):
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

    @Published var spots: [Spot] = []
    @Published var currentIndex: Int = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isEmpty = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var panelState: PanelState = .hidden
    @Published private(set) var countdownRemaining: Int = 0

    let catalogStore = CatalogStore.shared
    private let apiClient = APIClient.shared
    private var countdownTask: Task<Void, Never>?
    private var preloadTask: Task<Void, Never>?
    private static let countdownDuration = 10
    private static let skipTermID = 74

    var currentSpot: Spot? {
        guard currentIndex >= 0, currentIndex < spots.count else { return nil }
        return spots[currentIndex]
    }

    var isSubmitting: Bool {
        if case .submitting = panelState { return true }
        return false
    }

    var isPanelVisible: Bool {
        switch panelState {
        case .submitting, .showing:
            return true
        default:
            return false
        }
    }

    // MARK: - Loading

    func loadInitial() async {
        async let catalogRefresh: () = catalogStore.refresh()
        async let spotsLoad: () = loadFirstTwoSpots()
        _ = await (catalogRefresh, spotsLoad)
    }

    /// Loads two spots while the spinner is showing so the TabView
    /// has a next page ready without any mid-session flash.
    private func loadFirstTwoSpots() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let first = try await apiClient.fetchNextSpot() else {
                isEmpty = true
                return
            }

            let second = try? await apiClient.fetchNextSpot(excluding: [first.id])

            spots = [first]
            if let second {
                spots.append(second)
                _ = PlayerCache.shared.player(for: second.videoURL)
            }

            preloadNextSpot()
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

        let excludeIDs = spots.suffix(2).map(\.id)
        do {
            if let spot = try await apiClient.fetchNextSpot(excluding: excludeIDs) {
                spots.append(spot)
                currentIndex = spots.count - 1
                preloadNextSpot()
            } else {
                isEmpty = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func preloadNextSpot() {
        preloadTask?.cancel()
        preloadTask = Task {
            let excludeIDs = spots.suffix(3).map(\.id)
            if let spot = try? await apiClient.fetchNextSpot(excluding: excludeIDs) {
                guard !Task.isCancelled else { return }
                if !spots.contains(where: { $0.id == spot.id }) {
                    _ = PlayerCache.shared.player(for: spot.videoURL)
                    spots.append(spot)
                }
            }
        }
    }

    // MARK: - Skip (swipe forward)

    func submitSkip(at index: Int) {
        guard index >= 0, index < spots.count else { return }
        let spot = spots[index]
        Task {
            let skip = Identification(spotID: spot.id, speciesID: Self.skipTermID)
            _ = try? await apiClient.submitIdentification(skip)
        }
        if currentIndex >= spots.count - 2 {
            preloadNextSpot()
        }
    }

    // MARK: - Identification (species tap)

    func submitIdentification(species: Species) async {
        guard let spot = currentSpot else { return }

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
            panelState = .hidden
            errorMessage = error.localizedDescription
        }
    }

    func advanceToNextSpot() async {
        cancelCountdown()
        panelState = .hidden

        if currentIndex + 1 < spots.count {
            currentIndex += 1
            preloadNextSpot()
        } else {
            isLoading = true
            let excludeIDs = spots.suffix(2).map(\.id)
            do {
                if let spot = try await apiClient.fetchNextSpot(excluding: excludeIDs) {
                    spots.append(spot)
                    currentIndex += 1
                    preloadNextSpot()
                } else {
                    isEmpty = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
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
}
