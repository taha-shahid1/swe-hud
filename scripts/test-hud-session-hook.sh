#!/bin/bash
# Self-check for hud-session-hook.sh's overlay-file writes (skips the Stop distill).
set -euo pipefail
hook="$(dirname "$0")/hud-session-hook.sh"
export HUD_NOTES=$(mktemp -d)/session-notes.json
fire() { echo "{\"hook_event_name\":\"$1\",\"session_id\":\"$2\"}" | "$hook"; }
get() { /usr/bin/jq -c "$1" "$HUD_NOTES"; }

fire Notification a
[ "$(get '.a.needsYou')" = true ]
fire PostToolUse a
[ "$(get '.a.needsYou')" = false ]
fire Notification a; fire UserPromptSubmit a
[ "$(get '.a.needsYou')" = false ]

# Concurrent writers must not clobber each other.
for i in $(seq 1 20); do fire Notification "s$i" & done; wait
[ "$(get 'keys | length')" = 21 ]

fire SessionEnd a
[ "$(get 'has("a")')" = false ]
echo "ok"
