import Foundation
import Observation

/// `claude agents --json` is Claude Code's own authoritative live list of
/// real sessions (pid, cwd, busy/idle) — polling it directly, instead of
/// reconstructing session existence from a stream of async hook events,
/// sidesteps a whole category of bugs: ghost entries from internal
/// utility processes, duplicate/raced upserts, and stale-timeout logic
/// (a session that crashed just isn't in the list anymore — nothing to
/// time out). The hook script (`~/.claude/hud-session-hook.sh`) now only
/// writes the two things polling can't provide: the "needs you" flag and
/// the distilled note, into a small overlay file keyed by session ID,
/// which this store merges in and watches for changes (no polling there).
@Observable
final class SessionStore {
    private(set) var sessions: [SessionItem] = []

    private let overlayFileURL: URL
    private var overlayWatcher: FileWatcher?
    private var pollTimer: Timer?
    private var branchCache: [String: String] = [:]

    private static let pollInterval: TimeInterval = 5

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HUD", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        overlayFileURL = dir.appendingPathComponent("session-notes.json")
        if !FileManager.default.fileExists(atPath: overlayFileURL.path) {
            try? "{}".data(using: .utf8)?.write(to: overlayFileURL)
        }

        overlayWatcher = FileWatcher(url: overlayFileURL) { [weak self] in
            self?.refresh()
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    deinit {
        pollTimer?.invalidate()
    }

    var sorted: [SessionItem] {
        sessions.sorted { a, b in
            if a.state.sortPriority != b.state.sortPriority {
                return a.state.sortPriority < b.state.sortPriority
            }
            return a.updatedAt > b.updatedAt
        }
    }

    private func refresh() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let agents = Self.fetchAgents()
            let overlay = Self.loadOverlay(self.overlayFileURL)
            let merged = agents
                .filter { $0.kind == "interactive" }
                .map { self.buildItem(from: $0, overlay: overlay[$0.sessionId]) }
            DispatchQueue.main.async {
                self.sessions = merged
            }
        }
    }

    private func buildItem(from agent: AgentEntry, overlay: OverlayEntry?) -> SessionItem {
        let needsYou = overlay?.needsYou ?? false
        return SessionItem(
            id: agent.sessionId,
            cwd: agent.cwd,
            branch: branch(for: agent.cwd),
            state: needsYou ? .needsYou : (agent.status == "busy" ? .working : .idle),
            note: overlay?.note,
            notedAt: overlay?.notedAt,
            tty: Self.tty(forPID: agent.pid),
            pid: Int32(agent.pid),
            updatedAt: Date()
        )
    }

    private func branch(for cwd: String) -> String? {
        if let cached = branchCache[cwd] { return cached }
        let value = Self.gitBranch(cwd: cwd)
        if let value { branchCache[cwd] = value }
        return value
    }

    // MARK: - Shelling out

    private static let claudeFallbackPaths = [
        "\(NSHomeDirectory())/.local/bin/claude",
        "/opt/homebrew/bin/claude",
        "/usr/local/bin/claude",
    ]

    /// A GUI app launched outside a shell gets a minimal PATH (no
    /// `.zshrc`), so a bare lookup can miss an install that works fine in
    /// Terminal. Check PATH first, then a few common install locations.
    private static func resolveClaudeBinary() -> String? {
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for dir in path.split(separator: ":") {
                let candidate = "\(dir)/claude"
                if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
            }
        }
        return claudeFallbackPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func run(_ executable: String, _ arguments: [String]) -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return Data()
        }
        process.waitUntilExit()
        return outPipe.fileHandleForReading.readDataToEndOfFile()
    }

    private static func fetchAgents() -> [AgentEntry] {
        guard let bin = resolveClaudeBinary() else { return [] }
        let data = run(bin, ["agents", "--json"])
        return (try? JSONDecoder().decode([AgentEntry].self, from: data)) ?? []
    }

    private static func gitBranch(cwd: String) -> String? {
        let data = run("/usr/bin/git", ["-C", cwd, "rev-parse", "--abbrev-ref", "HEAD"])
        let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty ?? true) ? nil : value
    }

    private static func tty(forPID pid: Int) -> String? {
        let data = run("/bin/ps", ["-o", "tty=", "-p", "\(pid)"])
        let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty, value != "??" else { return nil }
        return "/dev/\(value)"
    }

    private static func loadOverlay(_ url: URL) -> [String: OverlayEntry] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([String: OverlayEntry].self, from: data)) ?? [:]
    }
}

private struct AgentEntry: Decodable {
    let pid: Int
    let cwd: String
    let kind: String
    let sessionId: String
    let status: String
}

private struct OverlayEntry: Decodable {
    let needsYou: Bool?
    let note: String?
    let notedAt: Date?
}
