#!/bin/sh
# Builds AirPointer.app and prints where it is.
#
# Build products go to ~/Library/Caches/AirPointer rather than into the project, so the
# project folder stays a few megabytes and is safe to keep somewhere that syncs.
set -e
cd "$(dirname "$0")/.."
CACHE="${AIRPOINTER_BUILD_DIR:-$HOME/Library/Caches/AirPointer}"
xcodegen generate --quiet
xcodebuild -project AirPointer.xcodeproj -scheme AirPointer -configuration Release \
  -derivedDataPath "$CACHE/DerivedData" build 2>&1 \
  | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)" | grep -v "appintents" || true
APP="$CACHE/DerivedData/Build/Products/Release/AirPointer.app"
[ -d "$APP" ] || { echo "Build failed: no app at $APP" >&2; exit 1; }
echo "$APP"
