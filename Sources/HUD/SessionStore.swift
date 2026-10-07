import AppKit
import Observation

/// `claude agents --json` is Claude Code's own authoritative live list of
/// real sessions (pid, cwd, busy/idle) — polling it directly, instead of
/// reconstructing session existence from a stream of async hook events,
/// sidesteps a whole category of bugs: ghost entries from internal
/// utility processes, duplicate/raced upserts, and stale-timeout logic
/// (a session that crashed just isn't in the list anymore — nothing to
/// time out). Notes are Claude Code's own `/recap` text, read from each
/// transcript. The hook script (`scripts/hud-session-hook.sh`) writes the
/// one thing neither provides, the "needs you" flag, into an overlay file
/// this store watches.
@Observable
final class SessionStore {
    private(set) var sessions: [SessionItem] = []

    private let overlayFileURL: URL
    private var overlayWatcher: FileWatcher?
    private var pollTimer: Timer?
    private var transcriptCache: [String: URL] = [:]
    private let recaps = RecapReader()
    /// Serial, so overlapping refreshes (timer + file watcher) can't race on the caches.
    private let refreshQueue = DispatchQueue(label: "SessionStore.refresh", qos: .utility)

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
        refreshQueue.async { [weak self] in
            guard let self else { return }
            // Dev affordance: render canned sessions (with --snapshot) without
            // touching live sessions or tmux.
            if let path = ProcessInfo.processInfo.environment["HUD_FAKE_SESSIONS"],
               let data = FileManager.default.contents(atPath: path),
               let fake = try? JSONDecoder().decode([SessionItem].self, from: data)
            {
                DispatchQueue.main.async { self.sessions = fake }
                return
            }
            let agents = Self.fetchAgents()
            let overlay = Self.loadOverlay(self.overlayFileURL)
            let panes = Self.tmuxPaneAttachment()
            let merged = agents.compactMap { self.buildItem(from: $0, overlay: overlay[$0.sessionId], panes: panes) }
            DispatchQueue.main.async {
                self.sessions = merged
            }
        }
    }

    private func buildItem(
        from agent: AgentEntry, overlay: OverlayEntry?, panes: [String: Bool]
    ) -> SessionItem? {
        let background = agent.kind == "background"
        guard background || (agent.kind == "interactive" && agent.pid != nil) else { return nil }
        let tty = agent.pid.flatMap(Self.tty(forPID:))
        // A background agent has no terminal at all, same as a detached tmux session.
        let detached = background || tty.flatMap { panes[$0] } == false
        let state: SessionState =
            overlay?.needsYou == true || agent.state == "blocked" ? .needsYou
            : detached ? .detached
            : agent.status == "busy" ? .working : .idle
        let recap = transcript(for: agent.sessionId).flatMap { recaps.recap(in: $0) }
        return SessionItem(
            id: agent.sessionId,
            name: agent.name,
            cwd: agent.cwd,
            branch: Self.gitBranch(cwd: agent.cwd),
            state: state,
            note: recap?.text,
            notedAt: recap?.at,
            tty: tty,
            pid: agent.pid.map(Int32.init),
            attachID: background ? (agent.id ?? agent.sessionId) : nil,
            updatedAt: Date()
        )
    }

    /// `~/.claude/projects/<encoded cwd>/<session id>.jsonl`. Found by scanning,
    /// not by re-deriving Claude's cwd encoding.
    private func transcript(for sessionID: String) -> URL? {
        if let cached = transcriptCache[sessionID] { return cached }
        let projects = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/projects")
        let dirs = (try? FileManager.default.contentsOfDirectory(at: projects, includingPropertiesForKeys: nil)) ?? []
        let found = dirs
            .map { $0.appendingPathComponent("\(sessionID).jsonl") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
        if let found { transcriptCache[sessionID] = found }
        return found
    }

    // MARK: - Shelling out

    private static let fallbackDirs = [
        "\(NSHomeDirectory())/.local/bin",
        "/opt/homebrew/bin",
        "/usr/local/bin",
    ]

    /// A GUI app launched outside a shell gets a minimal PATH (no
    /// `.zshrc`), so a bare lookup can miss an install that works fine in
    /// Terminal. Check PATH first, then a few common install locations.
    private static func resolveBinary(_ name: String) -> String? {
        let pathDirs = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        return (pathDirs + fallbackDirs)
            .map { "\($0)/\(name)" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
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
        guard let bin = resolveBinary("claude") else { return [] }
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

    // MARK: - Jumping to a session

    /// Brings the session's terminal to the front. In tmux: switch the most
    /// recently active client to the session's pane, then raise that client.
    func jump(to session: SessionItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let id = session.attachID {
                guard let claude = Self.resolveBinary("claude") else { return }
                DispatchQueue.main.async { Self.openTerminal(claude, ["attach", id]) }
                return
            }
            var hostTTY = session.tty
            var hostPID = session.pid.map(Int.init)
            if let tty = session.tty, let tmux = Self.resolveBinary("tmux"),
               let pane = Self.fields(Self.run(tmux, ["list-panes", "-a", "-F", "#{pane_tty} #{pane_id}"]))
                   .first(where: { $0.first == tty })?.last
            {
                _ = Self.run(tmux, ["select-window", "-t", pane])
                _ = Self.run(tmux, ["select-pane", "-t", pane])
                guard let client = Self.fields(Self.run(tmux, ["list-clients", "-F", "#{client_activity} #{client_tty} #{client_pid}"]))
                    .filter({ $0.count == 3 })
                    .max(by: { (Int($0[0]) ?? 0) < (Int($1[0]) ?? 0) })
                else {
                    // No terminal attached anywhere: open one on this pane.
                    DispatchQueue.main.async { Self.openTerminal(tmux, ["attach", "-t", pane]) }
                    return
                }
                // Explicit -c: run from outside tmux there's no "current client".
                _ = Self.run(tmux, ["switch-client", "-c", client[1], "-t", pane])
                hostTTY = client[1]
                hostPID = Int(client[2])
            }
            guard let hostPID, let app = Self.hostingApp(of: hostPID) else { return }
            DispatchQueue.main.async { Self.bringForward(app, tty: hostTTY) }
        }
    }

    /// Terminal.app: raise the exact window/tab by tty (Automation permission,
    /// asked once). Then activate through LaunchServices — a background app's
    /// plain `activate()` request is ignored under macOS 14 cooperative activation.
    private static func bringForward(_ app: NSRunningApplication, tty: String?) {
        if app.bundleIdentifier == "com.apple.Terminal",
           let tty, tty.range(of: #"^/dev/ttys\d+$"#, options: .regularExpression) != nil
        {
            let script = """
            tell application "Terminal"
                repeat with w in windows
                    repeat with t in tabs of w
                        if tty of t is "\(tty)" then
                            set selected of t to true
                            set index of w to 1
                        end if
                    end repeat
                end repeat
            end tell
            """
            NSAppleScript(source: script)?.executeAndReturnError(nil)
        }
        guard let url = app.bundleURL else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config)
    }

    /// New Terminal window running `binary args...`: `tmux attach -t %id` (which
    /// also makes that pane current) or `claude attach <id>`. Same Automation
    /// permission as bringForward. Validated: it's spliced into AppleScript, then a shell.
    private static func openTerminal(_ binary: String, _ args: [String]) {
        guard !binary.contains(where: { "\"\\'".contains($0) }),
              args.allSatisfy({ $0.range(of: #"^[%A-Za-z0-9-]+$"#, options: .regularExpression) != nil })
        else { return }
        let script = """
        tell application "Terminal"
            do script "'\(binary)' \(args.joined(separator: " "))"
            activate
        end tell
        """
        NSAppleScript(source: script)?.executeAndReturnError(nil)
    }

    /// Nearest ancestor (or self) that's a GUI app: Terminal, iTerm, Ghostty, VS Code...
    private static func hostingApp(of pid: Int) -> NSRunningApplication? {
        var parent: [Int: Int] = [:]
        for line in lines(run("/bin/ps", ["-axo", "pid=,ppid="])) {
            let parts = line.split(separator: " ").compactMap { Int($0) }
            if parts.count == 2 { parent[parts[0]] = parts[1] }
        }
        var current: Int? = pid
        while let p = current, p > 1 {
            if let app = NSRunningApplication(processIdentifier: pid_t(p)) { return app }
            current = parent[p]
        }
        return nil
    }

    private static func lines(_ data: Data) -> [String] {
        (String(data: data, encoding: .utf8) ?? "")
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func fields(_ data: Data) -> [[String]] {
        lines(data).map { $0.split(separator: " ").map(String.init) }
    }

    /// pane tty -> whether its tmux session has a terminal attached. Empty when
    /// tmux isn't installed or no server is running.
    private static func tmuxPaneAttachment() -> [String: Bool] {
        guard let tmux = resolveBinary("tmux") else { return [:] }
        var result: [String: Bool] = [:]
        for f in fields(run(tmux, ["list-panes", "-a", "-F", "#{pane_tty} #{session_attached}"])) where f.count == 2 {
            result[f[0]] = (Int(f[1]) ?? 0) > 0
        }
        return result
    }

    private static func loadOverlay(_ url: URL) -> [String: OverlayEntry] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([String: OverlayEntry].self, from: data)) ?? [:]
    }
}

/// Optional fields: background agents carry no `pid`/`status` (they have a short
/// `id` and a `state` instead), and one non-optional miss would fail decoding
/// of the whole array.
private struct AgentEntry: Decodable {
    let id: String?
    let pid: Int?
    let cwd: String
    let kind: String
    let sessionId: String
    let name: String?
    let status: String?
    let state: String?
}

private struct OverlayEntry: Decodable {
    let needsYou: Bool?
}
