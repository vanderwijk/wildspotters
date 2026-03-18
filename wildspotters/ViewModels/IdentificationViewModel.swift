import UIKit
import Combine

@MainActor
final class IdentificationViewModel: ObservableObject {

    @Published private(set) var currentSpot: Spot?
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var isEmpty = false
    @Published private(set) var errorMessage: String?

    let catalogStore = CatalogStore.shared
    private let apiClient = APIClient.shared

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

    func submitIdentification(speciesID: Int) async {
        guard let spot = currentSpot else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let identification = Identification(spotID: spot.id, speciesID: speciesID)

        do {
            try await apiClient.submitIdentification(identification)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            currentSpot = nil
            await loadNextSpot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
