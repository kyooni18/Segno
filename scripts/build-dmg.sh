#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 /path/to/Segno.app [output.dmg]" >&2
  exit 2
fi

APP_PATH="$1"
OUTPUT_PATH="${2:-dist/Segno.dmg}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKGROUND_SVG="$PROJECT_ROOT/Distribution/DMG/Background.svg"
BACKGROUND_PNG="$PROJECT_ROOT/Distribution/DMG/Background.png"

if [[ ! -d "$APP_PATH" || "$(basename "$APP_PATH")" != "Segno.app" ]]; then
  echo "Expected a built Segno.app bundle: $APP_PATH" >&2
  exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "Install create-dmg before building the installer image." >&2
  exit 1
fi
if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "Install librsvg (rsvg-convert) before building the installer image." >&2
  exit 1
fi

rsvg-convert "$BACKGROUND_SVG" -o "$BACKGROUND_PNG"
mkdir -p "$(dirname "$OUTPUT_PATH")"
OUTPUT_PATH="$(cd "$(dirname "$OUTPUT_PATH")" && pwd)/$(basename "$OUTPUT_PATH")"

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/segno-dmg.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
ditto "$APP_PATH" "$STAGING_DIR/Segno.app"

create-dmg \
  --overwrite \
  --volname "Segno" \
  --background "$BACKGROUND_PNG" \
  --window-pos 200 120 \
  --window-size 760 500 \
  --icon-size 128 \
  --icon "Segno.app" 190 260 \
  --app-drop-link 570 260 \
  --hide-extension "Segno.app" \
  "$OUTPUT_PATH" \
  "$STAGING_DIR"

echo "Created $OUTPUT_PATH"
