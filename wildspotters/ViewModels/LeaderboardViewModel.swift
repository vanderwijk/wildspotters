import Combine
import Foundation

@MainActor
final class LeaderboardViewModel: ObservableObject {

    @Published private(set) var response: LeaderboardResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            response = try await APIClient.shared.fetchLeaderboard(limit: 25)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
