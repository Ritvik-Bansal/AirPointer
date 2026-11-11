#!/bin/sh
# Makes what the project's README shows at its top, from the rendered spot:
#
#   docs/airpointer-spot.webp   the film as a moving picture, without sound: 1280x720, 15 frames a second
#   docs/airpointer-spot.mp4    the film with its sound, for the link on it (the copy under 10 MB)
#
# GitHub plays a video in a README only if it was uploaded by hand in the browser. A moving
# picture needs no upload, plays by itself and loops, so the README shows that and links to
# the film.
#
# Run Video/Spot/render.sh first. Needs ffmpeg and img2webp (brew install ffmpeg webp).
set -e
cd "$(dirname "$0")/../../.."
FILM=Video/out/airpointer-spot.mp4
WEB=Video/out/airpointer-spot-web.mp4
FRAMES="${AIRPOINTER_BUILD_DIR:-$HOME/Library/Caches/AirPointer}/Spot/readme-clip"
for tool in ffmpeg img2webp; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool is needed and was not found. Install it with: brew install ffmpeg webp" >&2; exit 1; }
done
[ -f "$FILM" ] && [ -f "$WEB" ] || { echo "The spot has not been rendered yet. Run Video/Spot/render.sh first." >&2; exit 1; }

rm -rf "$FRAMES"
mkdir -p "$FRAMES" docs
ffmpeg -hide_banner -loglevel error -y -i "$FILM" -vf "fps=15,scale=1280:720:flags=lanczos" "$FRAMES/f%04d.png"
# 67 ms to a frame is 15 frames a second. Quality 65 keeps the dark tones free of banding.
img2webp -loop 0 -lossy -q 65 -m 4 -d 67 "$FRAMES"/f*.png -o docs/airpointer-spot.webp >/dev/null
cp "$WEB" docs/airpointer-spot.mp4
rm -rf "$FRAMES"

for f in docs/airpointer-spot.webp docs/airpointer-spot.mp4; do
  printf "%-28s %5.1f MB\n" "$f" "$(stat -f %z "$f" | awk '{ print $1 / 1000000 }')"
done
