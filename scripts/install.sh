#!/bin/bash
# Build a release binary and run it as a LaunchAgent: starts at login,
# relaunches if it dies. Re-run after code changes to rebuild + restart.
set -euo pipefail
cd "$(dirname "$0")/.."

# CLT's macOS 27 SDK lacks the SwiftUI macro plugin; 26.5 builds fine.
export SDKROOT=${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}
swift build -c release

label=com.tahashahid.hud
plist="$HOME/Library/LaunchAgents/$label.plist"
cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key><array><string>$PWD/.build/release/HUD</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$plist"
echo "HUD running ($label)"
