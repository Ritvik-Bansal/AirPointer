#!/bin/sh
# Replays a recorded trace through the engine and prints what the cursor would have done.
#   scripts/replay.sh <trace> [--speed 1.0] [--acceleration 0.7] [--steadiness 0.5]
#                             [--sensitivity 0.5] [--calibrate <phase>] [--path <phase>]
set -e
cd "$(dirname "$0")/.."
CACHE="${AIRPOINTER_BUILD_DIR:-$HOME/Library/Caches/AirPointer}"
swift run -c release --package-path Packages/PointerKit --scratch-path "$CACHE/PointerKit" pointer-replay "$@"
