#!/bin/sh
# Renders the 30-second AirPointer spot.
#
#   Video/Spot/render.sh                 the film, a poster frame, and a copy small enough for GitHub
#   Video/Spot/render.sh --4k            the same at 3840x2160
#   Video/Spot/render.sh --draft         a quick look: half size, few samples
#   Video/Spot/render.sh --samples 192   more renders averaged into each frame (default 96)
#   Video/Spot/render.sh --address "github.com/you/AirPointer"     the line on the end card
#
# The picture is a Three.js scene drawn frame by frame in headless Chrome; the sound is
# synthesised from the same timeline; ffmpeg puts them together. Everything built on the way
# (node_modules, the baked model, frames) goes to ~/Library/Caches/AirPointer/Spot, so this
# folder stays small and safe to keep somewhere that syncs.
set -e
cd "$(dirname "$0")"
CACHE="${AIRPOINTER_BUILD_DIR:-$HOME/Library/Caches/AirPointer}/Spot"
WORK="$CACHE/work"
for tool in node npm ffmpeg ffprobe; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool is needed and was not found (brew install node ffmpeg)." >&2; exit 1; }
done

SCALE=1; SAMPLES=96; NAME=airpointer-spot
while [ $# -gt 0 ]; do
  case "$1" in
    --4k) SCALE=2; shift ;;
    --draft) SCALE=0.5; SAMPLES=12; NAME=airpointer-spot-draft; shift ;;
    --samples) SAMPLES="$2"; shift 2 ;;
    *) break ;;
  esac
done

mkdir -p "$CACHE" "$WORK" ../out
if [ ! -d "$CACHE/node_modules/three" ] || ! cmp -s package-lock.json "$CACHE/package-lock.json"; then
  cp package.json package-lock.json "$CACHE/"
  (cd "$CACHE" && npm ci --no-audit --no-fund --silent)
fi
export SPOT_CACHE="$CACHE"

node tools/bake.mjs "$CACHE/meshes"
node tools/render.mjs sound "$WORK/sound.wav" "$@"
# (caffeinate keeps the Mac awake for the length of the render. A run that is interrupted
# can simply be started again: frames already drawn are kept if nothing has changed.)
caffeinate -i node tools/render.mjs film "$WORK/picture.mp4" --scale "$SCALE" --samples "$SAMPLES" "$@"

