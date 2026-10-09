# HUD

A macOS menu bar overlay for keeping track of what you're working on and every running Claude Code session.

Press **⌥Tab** anywhere to toggle two glass panels:

- **Threads** (left): your own list of work items, grouped by status: needs you, working, waiting on someone, done.
- **Sessions** (right): a live grid of Claude Code sessions with busy/idle state, a "needs you" flag, and each session's latest `/recap`. Sessions in detached tmux sessions get their own section.

The menu bar icon shows how many threads aren't done yet.

## Requirements

- macOS 15+
- Swift 5.10+ (Xcode or Command Line Tools)
- Claude Code (`claude agents --json` is polled for sessions)
- `jq` at `/usr/bin/jq` for the session hook

## Install

```sh
scripts/install.sh
```

This builds a release binary and runs it as a LaunchAgent (`com.tahashahid.hud`), so it starts at login and relaunches if it dies. Re-run it after code changes.

For a quick dev run: `swift run HUD --show`.

### "Needs you" hook

To flag sessions that are waiting on you, register `scripts/hud-session-hook.sh` in `~/.claude/settings.json` for the `Notification`, `UserPromptSubmit`, `PostToolUse` and `SessionEnd` events:

```json
{
  "hooks": {
    "Notification":     [{ "hooks": [{ "type": "command", "command": "/path/to/swe-hud/scripts/hud-session-hook.sh" }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "/path/to/swe-hud/scripts/hud-session-hook.sh" }] }],
    "PostToolUse":      [{ "hooks": [{ "type": "command", "command": "/path/to/swe-hud/scripts/hud-session-hook.sh" }] }],
    "SessionEnd":       [{ "hooks": [{ "type": "command", "command": "/path/to/swe-hud/scripts/hud-session-hook.sh" }] }]
  }
}
```

Jumping into a session drives Terminal via Apple Events, so macOS will ask for Automation permission the first time.

## Keys

| Key | Where | Action |
| --- | --- | --- |
| ⌥Tab | anywhere | Toggle the HUD |
| Esc | HUD | Hide |
| N | threads | New thread |
| ↑ / ↓ | threads | Move selection |
| ⌥↑ / ⌥↓ | threads | Reorder within its status group (or drag) |
| Return | threads | Edit selected thread |
| Tab | threads | Cycle status |
| Delete | threads | Delete thread |
| ← / → | both | Switch between the panels |
| Arrows / Return | sessions | Move selection / jump to the session |
| 1–9 | both | Jump to session N |

Double-click a session tile to jump in. Right-click a thread to delete it.

## Data

Everything lives in `~/Library/Application Support/HUD/`:

- `threads.json`: your threads
- `session-notes.json`: the "needs you" flags written by the hook

## Checks

```sh
scripts/test-hud-session-hook.sh
swiftc -o /tmp/order-check Sources/HUD/ThreadItem.swift Sources/HUD/ThreadStore.swift scripts/test-thread-order/main.swift && CFFIXED_USER_HOME=$(mktemp -d) /tmp/order-check
```
