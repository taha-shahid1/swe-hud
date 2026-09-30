import Foundation
import Observation

/// Loads sessions from the shared JSON file Claude Code hooks write to
/// (`~/.claude/hud-session-hook.sh`, registered in `~/.claude/settings.json`),
/// watching it for changes with no polling. Until a hook actually writes
/// something, this seeds a few illustrative sample rows in memory only, so
/// the grid UI has something to show without polluting the on-disk file
/// real hook data owns.
@Observable
final class SessionStore {
    private(set) var sessions: [SessionItem] = []

    private let fileURL: URL
    private var watcher: FileWatcher?
    private var staleTimer: Timer?
    private var isShowingDemoData = false
    /// Read (but otherwise unused) inside `sorted` purely so Observation
    /// tracks it as a dependency — staleness is a function of wall-clock
    /// time, not of any stored property, so without this the UI would
    /// never re-evaluate it once the store stops receiving writes.
    private var tick = 0

    private static let staleThreshold: TimeInterval = 10 * 60

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HUD", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("sessions.json")

        load()
        if sessions.isEmpty {
            seedSampleData()
            isShowingDemoData = true
        }

        watcher = FileWatcher(url: fileURL) { [weak self] in
            self?.reloadFromDisk()
        }

        staleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.tick += 1
        }
    }

    deinit {
        staleTimer?.invalidate()
    }

    /// Sorted by what needs you, with a live staleness override — a
    /// session stuck on "working" past the timeout displays as stale
    /// without needing to rewrite the hook-owned file on disk.
    var sorted: [SessionItem] {
        _ = tick
        return sessions
            .map(Self.applyingStaleOverride)
            .sorted { a, b in
                if a.state.sortPriority != b.state.sortPriority {
                    return a.state.sortPriority < b.state.sortPriority
                }
                return a.updatedAt > b.updatedAt
            }
    }

    private static func applyingStaleOverride(_ session: SessionItem) -> SessionItem {
        guard session.state == .working,
              Date().timeIntervalSince(session.updatedAt) > staleThreshold
        else { return session }
        var stale = session
        stale.state = .stale
        return stale
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        sessions = Self.decode(data)
    }

    private func reloadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let loaded = Self.decode(data)
        if loaded.isEmpty && isShowingDemoData {
            return // a still-empty file shouldn't clobber the demo rows
        }
        sessions = loaded
        isShowingDemoData = false
    }

    private static func decode(_ data: Data) -> [SessionItem] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([SessionItem].self, from: data)) ?? []
    }

    private func seedSampleData() {
        let now = Date()
        sessions = [
            SessionItem(
                id: "demo-1", cwd: "/Users/demo/eng-482-fix-upload-bug", branch: "fix-upload-bug",
                state: .needsYou,
                note: "Blocked: migration file already exists, needs approval to overwrite.",
                notedAt: now.addingTimeInterval(-120), updatedAt: now.addingTimeInterval(-120)
            ),
            SessionItem(
                id: "demo-2", cwd: "/Users/demo/eng-491-retry-logic", branch: "retry-logic",
                state: .working, updatedAt: now.addingTimeInterval(-40)
            ),
            SessionItem(
                id: "demo-3", cwd: "/Users/demo/docs-fix", branch: "typo-pass", state: .idle,
                note: "Finished: fixed 12 typos across README and docs/.",
                notedAt: now.addingTimeInterval(-2400), updatedAt: now.addingTimeInterval(-2400)
            ),
            SessionItem(
                id: "demo-4", cwd: "/Users/demo/scratch", branch: "main", state: .stale,
                updatedAt: now.addingTimeInterval(-9000)
            ),
        ]
    }
}
