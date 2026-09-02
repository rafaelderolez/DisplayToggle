#!/bin/bash
# Builds DisplayToggle and installs it in /Applications, then restarts it.
# Requires Xcode Command Line Tools (xcode-select --install).
#
# Usage:
#   ./build.sh              build, install in /Applications, relaunch
#   ./build.sh --local      build next to this script instead (for testing)
#   ./build.sh --no-launch  install, but do not start the app
#   DEST=/some/dir ./build.sh   install in another folder
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="DisplayToggle.app"
DEST="${DEST:-/Applications}"
LAUNCH=1

for arg in "$@"; do
  case "$arg" in
    --local)     DEST="$PWD" ;;
    --no-launch) LAUNCH=0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/$APP_NAME"
mkdir -p "$APP/Contents/MacOS"

swiftc -O main.swift -o "$APP/Contents/MacOS/DisplayToggle" \
  -framework AppKit -framework Carbon -framework ServiceManagement

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>        <string>dev.derolez.DisplayToggle</string>
  <key>CFBundleName</key>              <string>DisplayToggle</string>
  <key>CFBundleExecutable</key>        <string>DisplayToggle</string>
  <key>CFBundlePackageType</key>       <string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key>           <string>1</string>
  <key>LSMinimumSystemVersion</key>    <string>13.0</string>
  <key>LSUIElement</key>               <true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"

# Stop the running copy, wherever it was started from. A menu bar app has no
# Dock icon and no AppleScript quit handler, so signal the process directly.
if pgrep -f "$APP_NAME/Contents/MacOS/DisplayToggle" >/dev/null; then
  echo "Stopping the running copy…"
  pkill -f "$APP_NAME/Contents/MacOS/DisplayToggle" || true
  for _ in $(seq 20); do
    pgrep -f "$APP_NAME/Contents/MacOS/DisplayToggle" >/dev/null || break
    sleep 0.2
  done
fi

TARGET="$DEST/$APP_NAME"
mkdir -p "$DEST"
rm -rf "$TARGET"
ditto "$APP" "$TARGET"

echo "Installed $TARGET"
if [ "$LAUNCH" = 1 ]; then
  open "$TARGET"
  echo "Started. Look for the display icon in the menu bar."
else
  echo "Run it with: open \"$TARGET\""
fi
