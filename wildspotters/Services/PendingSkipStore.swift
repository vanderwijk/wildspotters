import Foundation

/// Persists skipped spots that could not be submitted to the API yet.
final class PendingSkipStore {

    static let shared = PendingSkipStore()

    private let defaultsKey = "wildspotters_pending_skip_spot_ids"

    private init() {}

    func enqueue(_ spotID: Int) {
        guard 0 < spotID else { return }

        var ids = Set(pendingSpotIDs())
        ids.insert(spotID)
        save(ids)
    }

    func remove(_ spotID: Int) {
        guard 0 < spotID else { return }

        var ids = Set(pendingSpotIDs())
        ids.remove(spotID)
        save(ids)
    }

    func pendingSpotIDs() -> [Int] {
        let raw = UserDefaults.standard.array(forKey: defaultsKey) as? [Int] ?? []
        return raw.filter { 0 < $0 }.sorted()
    }

    private func save(_ ids: Set<Int>) {
        UserDefaults.standard.set(Array(ids).sorted(), forKey: defaultsKey)
    }
}
