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

# Bring the sound to -16 LUFS, or as near as leaves 1 dB under full scale.
MEASURED=$(ffmpeg -hide_banner -nostats -i "$WORK/sound.wav" -af loudnorm=print_format=json -f null - 2>&1)
LOUD=$(printf '%s' "$MEASURED" | awk -F'"' '/input_i/ { print $4 }')
PEAK=$(printf '%s' "$MEASURED" | awk -F'"' '/input_tp/ { print $4 }')
GAIN=$(awk -v i="$LOUD" -v p="$PEAK" 'BEGIN { g = -16 - i; h = -1 - p; if (h < g) g = h; printf "%.2f", g }')
ffmpeg -hide_banner -loglevel error -y -i "$WORK/picture.mp4" -i "$WORK/sound.wav" \
  -map 0:v -map 1:a -c:v copy -af "volume=${GAIN}dB" -c:a aac -b:a 256k -shortest -movflags +faststart "../out/$NAME.mp4"
echo "Sound: measured $LOUD LUFS, peak $PEAK dBTP; set ${GAIN} dB."

# The poster: the end card.
node tools/render.mjs stills "$WORK" 28.5 --scale "$SCALE" --samples "$SAMPLES" "$@" >/dev/null
mv "$WORK/t28.50.png" "../out/$NAME-poster.png"

# The copy for the web: GitHub takes video attachments up to 10 MB on a free account.
BYTES=$(stat -f %z "../out/$NAME.mp4")
LIMIT="${AIRPOINTER_WEB_BYTES:-9400000}"
if [ "$BYTES" -le "$LIMIT" ] && [ "$SCALE" != 2 ]; then
  cp "../out/$NAME.mp4" "../out/$NAME-web.mp4"
else
  SECONDS_LONG=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "../out/$NAME.mp4")
  PICTURE_KBPS=$(awk -v b="$LIMIT" -v s="$SECONDS_LONG" 'BEGIN { printf "%d", (b * 8 / s / 1000) * 0.95 - 160 }')
  PICTURE="-vf scale=1920:1080:flags=lanczos -c:v libx264 -preset slow -b:v ${PICTURE_KBPS}k -pix_fmt yuv420p -color_primaries bt709 -color_trc bt709 -colorspace bt709"
  ffmpeg -hide_banner -loglevel error -y -i "../out/$NAME.mp4" $PICTURE -pass 1 -passlogfile "$WORK/pass" -an -f null /dev/null
  ffmpeg -hide_banner -loglevel error -y -i "../out/$NAME.mp4" $PICTURE -pass 2 -passlogfile "$WORK/pass" -c:a aac -b:a 160k -movflags +faststart "../out/$NAME-web.mp4"
fi
rm -rf "$WORK"

echo
for f in "../out/$NAME.mp4" "../out/$NAME-web.mp4" "../out/$NAME-poster.png"; do
  printf "%-40s %6.1f MB\n" "Video/out/$(basename "$f")" "$(stat -f %z "$f" | awk '{ print $1 / 1000000 }')"
done
