#!/bin/bash
# Claude Code hook -> HUD overlay file: the "needs you" flag, keyed by session ID.
# Register for Notification, UserPromptSubmit, PostToolUse and SessionEnd.

NOTES=${HUD_NOTES:-"$HOME/Library/Application Support/HUD/session-notes.json"}
LOCK="$NOTES.lock"
JQ=/usr/bin/jq

mkdir -p "$(dirname "$NOTES")"
[ -s "$NOTES" ] || echo '{}' > "$NOTES"

input=$(cat)
event=$($JQ -r '.hook_event_name // empty' <<<"$input")
sid=$($JQ -r '.session_id // empty' <<<"$input")
[ -z "$sid" ] && exit 0

# Serialized read-modify-write, then atomic rename (FileWatcher handles it).
# Usage: update <jq filter> [jq args...]
update() {
  local filter=$1; shift
  /usr/bin/lockf -k "$LOCK" /bin/sh -c '
    tmp=$(mktemp "$0.XXXXXX") || exit 1
    if '"$JQ"' "$@" "$0" > "$tmp"; then mv "$tmp" "$0"; else rm -f "$tmp"; fi
  ' "$NOTES" --arg id "$sid" "$@" "$filter"
}

case "$event" in
  Notification)
    update '.[$id].needsYou = true'
    ;;
  UserPromptSubmit|PostToolUse)
    # PostToolUse fires constantly; only touch the file when there's a flag to clear.
    [ "$($JQ -r --arg id "$sid" '.[$id].needsYou // false' "$NOTES")" = true ] &&
      update '.[$id].needsYou = false'
    ;;
  SessionEnd)
    update 'del(.[$id])'
    ;;
esac
exit 0
