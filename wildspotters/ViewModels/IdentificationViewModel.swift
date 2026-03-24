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

    @Published private(set) var currentSpot: Spot?
    @Published private(set) var isLoading = false
    @Published private(set) var isEmpty = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var panelState: PanelState = .hidden
    @Published private(set) var countdownRemaining: Int = 0

    let catalogStore = CatalogStore.shared
    private let apiClient = APIClient.shared
    private var countdownTask: Task<Void, Never>?
    private static let countdownDuration = 10

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

    func loadInitial() async {
        async let catalogRefresh: () = catalogStore.refresh()
        async let spotLoad: () = loadNextSpot()
        _ = await (catalogRefresh, spotLoad)
    }

    func loadNextSpot() async {
        errorMessage = nil
        isEmpty = false
        isLoading = true
        defer { isLoading = false }

        do {
            currentSpot = try await apiClient.fetchNextSpot()
            isEmpty = currentSpot == nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

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
                // No panel data — advance immediately
                await advanceToNextSpot()
            }
        } catch {
            panelState = .hidden
            errorMessage = error.localizedDescription
        }
    }

    func advanceToNextSpot() async {
        cancelCountdown()
        panelState = .loadingNext
        currentSpot = nil
        await loadNextSpot()
        panelState = .hidden
    }

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
            // Clear the task reference before advancing so cancelCountdown()
            // doesn't cancel the task we're currently running in.
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
