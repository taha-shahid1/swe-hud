import Foundation

enum SessionState: String, Codable, CaseIterable {
    case needsYou
    case working
    case idle
    case stale

    /// Lower sorts first — same "what needs you" priority as threads.
    var sortPriority: Int {
        switch self {
        case .needsYou: return 0
        case .working: return 1
        case .idle: return 2
        case .stale: return 3
        }
    }

    var label: String {
        switch self {
        case .needsYou: return "needs you"
        case .working: return "working"
        case .idle: return "idle"
        case .stale: return "stale"
        }
    }
}

/// One Claude Code session. Populated by Claude Code hooks writing to the
/// shared store (not yet wired — see SessionStore). `id` is the Claude
/// session ID itself, not a locally-generated UUID: hooks upsert one
/// record per session by that ID.
struct SessionItem: Identifiable, Codable, Equatable {
    var id: String
    var cwd: String
    var branch: String?
    var state: SessionState
    /// Distilled by a headless `claude -p` pass over the transcript: what
    /// happened, what's blocked on me, next step. Facts only, no guessing.
    var note: String?
    var notedAt: Date?
    /// For jumping to the right terminal window/tab later.
    var tty: String?
    var pid: Int32?
    var updatedAt: Date = Date()

    var project: String {
        URL(fileURLWithPath: cwd).lastPathComponent
    }
}
