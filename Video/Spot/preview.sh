#!/bin/sh
# Opens the spot in the browser to watch and scrub, without rendering it.
# The picture is drawn live at reduced quality; the sound is the real one.
set -e
cd "$(dirname "$0")"
CACHE="${AIRPOINTER_BUILD_DIR:-$HOME/Library/Caches/AirPointer}/Spot"
if [ ! -d "$CACHE/node_modules/three" ]; then
  mkdir -p "$CACHE"
  cp package.json package-lock.json "$CACHE/"
  (cd "$CACHE" && npm ci --no-audit --no-fund --silent)
fi
export SPOT_CACHE="$CACHE"
node tools/bake.mjs "$CACHE/meshes"
exec node tools/render.mjs serve
