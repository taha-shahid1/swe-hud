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

    /// Grouped by what needs you: needs-you, working, waiting, done. Within
    /// a group, `threads` array order is the user's manual arrangement.
    var sorted: [ThreadItem] {
        threads.enumerated().sorted { a, b in
            if a.element.status.sortPriority != b.element.status.sortPriority {
                return a.element.status.sortPriority < b.element.status.sortPriority
            }
            return a.offset < b.offset
        }
        .map(\.element)
    }

    /// Moves a thread onto another's slot in the same status group: below it
    /// when moving down, above it when moving up.
    func move(_ id: UUID, to targetID: UUID) {
        guard id != targetID,
              let from = threads.firstIndex(where: { $0.id == id }),
              let to = threads.firstIndex(where: { $0.id == targetID }),
              threads[from].status == threads[to].status
        else { return }
        threads.insert(threads.remove(at: from), at: to)
        save()
    }

    /// Swaps with the visible neighbor; stops at the edge of the status group.
    func move(_ id: UUID, by delta: Int) {
        let items = sorted
        guard let idx = items.firstIndex(where: { $0.id == id }),
              items.indices.contains(idx + delta)
        else { return }
        move(id, to: items[idx + delta].id)
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

    func remove(_ id: UUID) {
        threads.removeAll { $0.id == id }
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
