#!/bin/bash
# Builds Kiku in Release and packages it into a distributable .dmg.
#
# Usage:
#   ./scripts/build_dmg.sh
#
# Optional — enable the weekly AI recap by passing your Gemini API key via env:
#   GEMINI_API_KEY=your_key ./scripts/build_dmg.sh
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Kiku"
BUILD_DIR="build"
DERIVED="$BUILD_DIR/DerivedData"
DMG_DIR="$BUILD_DIR/dmg"
DIST_DIR="dist"
DMG_PATH="$DIST_DIR/${APP_NAME}.dmg"
GEMINI_API_KEY="${GEMINI_API_KEY:-}"

echo "==> Generating Xcode project"
xcodegen generate

if [ -n "$GEMINI_API_KEY" ]; then
  echo "==> Gemini API key provided via env — weekly AI recap will be enabled"
else
  echo "==> No GEMINI_API_KEY set — weekly AI recap will be disabled (everything else works)"
fi

echo "==> Building ${APP_NAME} (Release)"
xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  -destination 'platform=macOS' \
  GEMINI_API_KEY="$GEMINI_API_KEY" \
  clean build | tail -5

APP_PATH="$DERIVED/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
  echo "!! Build product not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Staging .app for DMG"
rm -rf "$DMG_DIR" "$DMG_PATH"
mkdir -p "$DMG_DIR" "$DIST_DIR"
cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

echo "==> Creating DMG"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_DIR" \
  -ov -format UDZO \
  "$DMG_PATH"

echo "==> Done: $DMG_PATH"
