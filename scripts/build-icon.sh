#!/bin/bash
# Convert the selected PNG into the standard macOS icon representations.
set -euo pipefail
cd "$(dirname "$0")/.."
SOURCE="${1:-assets/AppIcon.png}"
if [[ "$#" -gt 1 || ! -f "$SOURCE" ]]; then
  echo "Usage: ./scripts/build-icon.sh [path/to/icon.png]" >&2
  exit 2
fi
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ICONSET="$STAGE/AppIcon.iconset"
mkdir -p "$ICONSET" assets
for size in 16 32 128 256 512; do
  sips -s format png -z "$size" "$size" "$SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -s format png -z "$double" "$double" "$SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o assets/AppIcon.icns
echo "Generated assets/AppIcon.icns"
