import Foundation
import Observation

/// Loads/saves threads as one small JSON file under Application Support.
@Observable
final class ThreadStore {
    private(set) var threads: [ThreadItem] = []

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HUD", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("threads.json")
        load()
    }

    /// Sorted by what needs you, not recency: needs-you first, then
    /// working, then waiting-on-someone, then done. Within a status,
    /// the longest-untouched thread surfaces first so nothing gets buried.
    var sorted: [ThreadItem] {
        threads.sorted { a, b in
            if a.status.sortPriority != b.status.sortPriority {
                return a.status.sortPriority < b.status.sortPriority
            }
            return a.updatedAt < b.updatedAt
        }
    }

    @discardableResult
    func add(key: String, title: String) -> ThreadItem {
        let item = ThreadItem(key: key, title: title, status: .working, summary: "No update yet.")
        threads.append(item)
        save()
        return item
    }

    func setNextStep(_ id: UUID, text: String) {
        guard let idx = threads.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        threads[idx].nextStep = trimmed.isEmpty ? nil : trimmed
        threads[idx].updatedAt = Date()
        save()
    }

    func setStatus(_ id: UUID, status: ThreadStatus) {
        guard let idx = threads.firstIndex(where: { $0.id == id }) else { return }
        threads[idx].status = status
        threads[idx].updatedAt = Date()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        threads = (try? decoder.decode([ThreadItem].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(threads) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
