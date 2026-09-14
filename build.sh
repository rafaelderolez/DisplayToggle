#!/bin/bash
# Build with Apple's Command Line Tools; no Homebrew or package dependencies.
set -euo pipefail
cd "$(dirname "$0")"

usage() {
  cat <<'EOF'
Usage: ./build.sh [options]

  (no options)   Build, install in /Applications, and relaunch
  --build-only   Write build/DisplayToggle.app; do not stop or launch the app
  --local        Install next to this script instead of /Applications
  --no-launch    Install without launching
  --universal    Build for both Apple Silicon and Intel
  --help         Show this help

Environment:
  DEST           Installation directory (default: /Applications)
  BUILD_DIR      Build-only output directory (default: ./build)
  SIGN_IDENTITY  Code-signing identity (default: - for local ad-hoc signing)
EOF
}

DEST="${DEST:-/Applications}"
BUILD_DIR="${BUILD_DIR:-$PWD/build}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
LAUNCH=1
BUILD_ONLY=0
UNIVERSAL=0
for arg in "$@"; do
  case "$arg" in
    --build-only) BUILD_ONLY=1 ;;
    --local) DEST="$PWD" ;;
    --no-launch) LAUNCH=0 ;;
    --universal) UNIVERSAL=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "$(uname -s)" != Darwin ]]; then
  echo "DisplayToggle requires macOS." >&2
  exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Install Apple's Command Line Tools first: xcode-select --install" >&2
  exit 1
fi

VERSION="$(cat VERSION)"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must contain a version such as 1.0.0." >&2
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/DisplayToggle.app"
mkdir -p "$APP/Contents/MacOS"
if [[ -f assets/AppIcon.icns ]]; then
  mkdir -p "$APP/Contents/Resources"
  cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi
SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCHS=("$(uname -m)")
if [[ "$UNIVERSAL" = 1 ]]; then ARCHS=(arm64 x86_64); fi
BINARIES=()
for arch in "${ARCHS[@]}"; do
  echo "Building DisplayToggle $VERSION for $arch (macOS 13+)…"
  xcrun swiftc -O -sdk "$SDK" -target "${arch}-apple-macosx13.0" \
    main.swift -o "$STAGE/DisplayToggle-$arch" \
    -framework AppKit -framework Carbon -framework ServiceManagement
  BINARIES+=("$STAGE/DisplayToggle-$arch")
done
if [[ "$UNIVERSAL" = 1 ]]; then
  xcrun lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/DisplayToggle"
else
  cp "${BINARIES[0]}" "$APP/Contents/MacOS/DisplayToggle"
fi

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>         <string>dev.derolez.DisplayToggle</string>
  <key>CFBundleName</key>               <string>DisplayToggle</string>
  <key>CFBundleExecutable</key>         <string>DisplayToggle</string>
  <key>CFBundlePackageType</key>        <string>APPL</string>
  <key>CFBundleShortVersionString</key> <string>$VERSION</string>
  <key>CFBundleVersion</key>            <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>     <string>13.0</string>
  <key>LSUIElement</key>                <true/>
</dict>
</plist>
EOF

if [[ -f "$APP/Contents/Resources/AppIcon.icns" ]]; then
  /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$APP/Contents/Info.plist"
fi
plutil -lint "$APP/Contents/Info.plist"
if [[ "$SIGN_IDENTITY" = - ]]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi
codesign --verify --strict "$APP"

if [[ "$BUILD_ONLY" = 1 ]]; then DEST="$BUILD_DIR"; LAUNCH=0; fi
TARGET="$DEST/DisplayToggle.app"
mkdir -p "$DEST"
# Never replace an unrelated directory or follow a symlink at the app path.
if [[ -L "$TARGET" ]] || { [[ -e "$TARGET" ]] && \
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$TARGET/Contents/Info.plist" 2>/dev/null || true)" != dev.derolez.DisplayToggle ]]; }; then
  echo "Refusing to replace a non-DisplayToggle bundle: $TARGET" >&2
  exit 1
fi

if [[ "$BUILD_ONLY" = 0 ]]; then
  # A menu bar app has no AppleScript quit handler.
  PROCESS_PATTERN='DisplayToggle\.app/Contents/MacOS/DisplayToggle$'
  if pgrep -f "$PROCESS_PATTERN" >/dev/null; then
    echo "Stopping the running copy…"
    pkill -f "$PROCESS_PATTERN" || true
    for ((attempt = 0; attempt < 20; attempt++)); do
      pgrep -f "$PROCESS_PATTERN" >/dev/null || break
      sleep 0.2
    done
    if pgrep -f "$PROCESS_PATTERN" >/dev/null; then
      echo "Quit DisplayToggle and retry the installation." >&2
      exit 1
    fi
  fi
fi

rm -rf "$TARGET"
ditto "$APP" "$TARGET"
echo "Built $TARGET"
if [[ "$LAUNCH" = 1 ]]; then
  open "$TARGET"
  echo "Started. Look for the display icon in the menu bar."
elif [[ "$BUILD_ONLY" = 0 ]]; then
  echo "Run it with: open \"$TARGET\""
fi
