import Combine
import Foundation

@MainActor
final class ProfileOverviewViewModel: ObservableObject {

    @Published private(set) var overview: ProfileOverviewResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var updatingAvatarSpeciesID: Int?
    @Published private(set) var avatarErrorMessage: String?

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            overview = try await APIClient.shared.fetchProfileOverview()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func setAvatar(speciesID: Int) async -> Bool {
        guard let overview, updatingAvatarSpeciesID == nil else { return false }
        guard overview.collection.first(where: { $0.speciesID == speciesID })?.isCurrentAvatar != true else { return false }

        updatingAvatarSpeciesID = speciesID
        avatarErrorMessage = nil
        defer { updatingAvatarSpeciesID = nil }

        do {
            let newAvatar = try await APIClient.shared.setProfileAvatar(speciesID: speciesID)
            let updatedCollection = overview.collection.map { item in
                ProfileCollectionItem(
                    speciesID: item.speciesID,
                    name: item.name,
                    scientificName: item.scientificName,
                    englishName: item.englishName,
                    germanName: item.germanName,
                    imageURL: item.imageURL,
                    isCurrentAvatar: item.speciesID == speciesID
                )
            }
            self.overview = ProfileOverviewResponse(
                avatar: newAvatar,
                stats: overview.stats,
                collection: updatedCollection,
                likes: overview.likes
            )
            return true
        } catch {
            avatarErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }
}
