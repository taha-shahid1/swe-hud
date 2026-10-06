import Foundation

enum SessionState: String, Codable, CaseIterable {
    case needsYou
    case working
    case idle
    /// Alive, but in a tmux session with no terminal attached: nobody can see it.
    case detached

    /// Lower sorts first — same "what needs you" priority as threads.
    var sortPriority: Int {
        switch self {
        case .needsYou: return 0
        case .working: return 1
        case .idle: return 2
        case .detached: return 3
        }
    }

    var label: String {
        switch self {
        case .needsYou: return "needs you"
        case .working: return "working"
        case .idle: return "idle"
        case .detached: return "detached"
        }
    }
}

/// One Claude Code session: `claude agents --json` merged with the hook
/// overlay (see SessionStore). `id` is the Claude session ID itself, not a
/// locally-generated UUID.
struct SessionItem: Identifiable, Codable, Equatable {
    var id: String
    /// Claude's session name (auto `<project>-<hex>`, or set via /rename) —
    /// unique, unlike project, when several sessions share a repo.
    var name: String?
    var cwd: String
    var branch: String?
    var state: SessionState
    /// Claude Code's latest `/recap` for the session, from its transcript.
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
