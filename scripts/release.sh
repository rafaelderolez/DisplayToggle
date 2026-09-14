#!/bin/bash
# Produce a universal ZIP and checksum. Does not install, launch, or publish.
set -euo pipefail
cd "$(dirname "$0")/.."

UNSIGNED=0
case "${1:-}" in
  --unsigned) UNSIGNED=1 ;;
  --help|-h)
    echo "Usage: SIGN_IDENTITY='Developer ID Application: …' NOTARY_PROFILE=… ./scripts/release.sh"
    echo "       ./scripts/release.sh --unsigned  # local/CI testing only"
    exit 0 ;;
  '') ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac
if [[ "$#" -gt 1 ]]; then echo "Too many arguments." >&2; exit 2; fi
if [[ "$UNSIGNED" = 0 ]]; then
  if [[ -z "${SIGN_IDENTITY:-}" || "${SIGN_IDENTITY:-}" = - || -z "${NOTARY_PROFILE:-}" ]]; then
    echo "Public releases require SIGN_IDENTITY and NOTARY_PROFILE." >&2
    echo "Use --unsigned only to test packaging without Developer ID credentials." >&2
    exit 1
  fi
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
if [[ "$UNSIGNED" = 1 ]]; then export SIGN_IDENTITY=-; fi
BUILD_DIR="$STAGE" ./build.sh --build-only --universal
APP="$STAGE/DisplayToggle.app"
VERSION="$(cat VERSION)"
NAME="DisplayToggle-$VERSION"
if [[ "$UNSIGNED" = 1 ]]; then
  NAME="$NAME-unsigned"
else
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$STAGE/notarize.zip"
  xcrun notarytool submit "$STAGE/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl --assess --type execute --verbose=2 "$APP"
fi

mkdir -p dist
ARCHIVE="$PWD/dist/$NAME.zip"
# ditto may update an existing archive; require a fresh filename for each run.
if [[ -e "$ARCHIVE" || -L "$ARCHIVE" ]]; then
  echo "Archive already exists: $ARCHIVE. Move it aside before rebuilding." >&2
  exit 1
fi
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
(
  cd dist
  shasum -a 256 "$NAME.zip" > "$NAME.zip.sha256"
)
echo "Release files: $ARCHIVE and $ARCHIVE.sha256"
if [[ "$UNSIGNED" = 1 ]]; then
  echo "This test build is ad-hoc signed, not notarized. Do not present it as a signed public release."
fi
