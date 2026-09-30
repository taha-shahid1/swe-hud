import Foundation

enum ThreadStatus: String, Codable, CaseIterable {
    case needsYou
    case working
    case waitingOnSomeone
    case done

    /// Lower sorts first. Threads are ordered by what needs you, not recency.
    var sortPriority: Int {
        switch self {
        case .needsYou: return 0
        case .working: return 1
        case .waitingOnSomeone: return 2
        case .done: return 3
        }
    }

    /// Manual status cycling, e.g. via a keystroke on the selected row.
    var next: ThreadStatus {
        switch self {
        case .working: return .needsYou
        case .needsYou: return .waitingOnSomeone
        case .waitingOnSomeone: return .done
        case .done: return .working
        }
    }
}

/// One row in the left panel. Named `ThreadItem` (not `Thread`) to avoid
/// shadowing `Foundation.Thread`.
struct ThreadItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var key: String
    var title: String
    var status: ThreadStatus
    var summary: String
    var nextStep: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}
