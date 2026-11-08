#!/bin/sh
# Runs the engine's tests, including the replays of recorded sessions.
set -e
cd "$(dirname "$0")/.."
CACHE="${AIRPOINTER_BUILD_DIR:-$HOME/Library/Caches/AirPointer}"
swift test --package-path Packages/PointerKit --scratch-path "$CACHE/PointerKit" "$@"
