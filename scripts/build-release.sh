#!/bin/zsh
# Builds a Release copy of the app and zips it for sending (ad-hoc signed; recipient uses right-click → Open once).
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="$PWD/build"
DERIVED="$OUT/DerivedData"
rm -rf "$OUT"
mkdir -p "$OUT"

xcodebuild \
  -project transcribe-clips.xcodeproj \
  -scheme transcribe-clips \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  build | grep -E "error:|warning:|BUILD" || true

APP="$DERIVED/Build/Products/Release/Clip Transcriber.app"
[[ -d "$APP" ]] || { echo "Build failed: $APP not found" >&2; exit 1; }

cp -R "$APP" "$OUT/"
ditto -c -k --keepParent "$OUT/Clip Transcriber.app" "$OUT/Clip Transcriber.zip"
echo "Ready: $OUT/Clip Transcriber.zip"
