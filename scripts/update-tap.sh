#!/bin/bash
# Generate the cask from a published, notarized release. Does not push the tap.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$#" != 1 || "${1:-}" = --help || "${1:-}" = -h ]]; then
  echo "Usage: ./scripts/update-tap.sh /path/to/homebrew-tap"
  if [[ "${1:-}" = --help || "${1:-}" = -h ]]; then exit 0; fi
  exit 2
fi
TAP="$(cd "$1" && pwd)"
TEMPLATE="$TAP/templates/displaytoggle.rb.erb"
if [[ ! -f "$TEMPLATE" ]]; then
  echo "Missing cask template: $TEMPLATE" >&2
  exit 1
fi
VERSION="$(cat "$ROOT/VERSION")"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid VERSION." >&2
  exit 1
fi
REPO=rafaelderolez/DisplayToggle
if [[ "$(gh repo view "$REPO" --json visibility --jq .visibility)" != PUBLIC ]]; then
  echo "The release repository must be public before Homebrew can download its app." >&2
  exit 1
fi
if [[ "$(gh release view "v$VERSION" --repo "$REPO" --json isDraft --jq .isDraft)" != false ]]; then
  echo "Publish the release before updating the tap." >&2
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
NAME="DisplayToggle-$VERSION.zip"
gh release download "v$VERSION" --repo "$REPO" --pattern "$NAME" --pattern "$NAME.sha256" --dir "$STAGE"
(
  cd "$STAGE"
  shasum -a 256 -c "$NAME.sha256"
)
ditto -x -k "$STAGE/$NAME" "$STAGE/unpacked"
APP="$STAGE/unpacked/DisplayToggle.app"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = dev.derolez.DisplayToggle
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" = "$VERSION"
xcrun lipo "$APP/Contents/MacOS/DisplayToggle" -verify_arch arm64 x86_64
codesign --verify --strict "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

SHA256="$(shasum -a 256 "$STAGE/$NAME" | awk '{print $1}')"
ruby -rerb -e 'version, sha256, template = ARGV; print ERB.new(File.read(template)).result(binding)' \
  "$VERSION" "$SHA256" "$TEMPLATE" > "$STAGE/displaytoggle.rb"
ruby -c "$STAGE/displaytoggle.rb"
mkdir -p "$TAP/Casks"
cp "$STAGE/displaytoggle.rb" "$TAP/Casks/displaytoggle.rb"
echo "Updated $TAP/Casks/displaytoggle.rb from the published release."
echo "Review, audit, test, then commit and push the tap."
