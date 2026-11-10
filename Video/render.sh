#!/bin/sh
# Renders the AirPointer film.
#
#   Video/render.sh          the film, a copy small enough to upload to GitHub, and a poster frame
#   Video/render.sh --4k     the same, with the film at 3840x2160
#
# Anything else on the line is handed to the film tool, for example --footage <folder>.
#
# The clips and the music come from Video/footage (see Video/README.md). While a clip is
# missing, its slot shows a card and the film is written as airpointer-base.mp4; once both
# are there it is written as airpointer.mp4.
#
# Everything built on the way goes to ~/Library/Caches/AirPointer, so this folder stays
# small and safe to keep somewhere that syncs.
set -e
cd "$(dirname "$0")"
CACHE="${AIRPOINTER_BUILD_DIR:-$HOME/Library/Caches/AirPointer}"
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg is needed and was not found. Install it with: brew install ffmpeg" >&2; exit 1; }

SCALE=1
if [ "$1" = "--4k" ]; then SCALE=2; shift; fi

swift build -c release --scratch-path "$CACHE/Film" 2>&1 | grep -E "error|Build complete" || true
FILM="$CACHE/Film/release/film"
[ -x "$FILM" ] || { echo "The film tool did not build." >&2; exit 1; }

mkdir -p out "$CACHE/Film/work"
DRAFT="$CACHE/Film/work/film.mp4"
LOG="$CACHE/Film/work/render.log"
"$FILM" render "$DRAFT" --scale "$SCALE" "$@" | tee "$LOG"

# A film that still shows a card is a base cut, and is named as one.
NAME=airpointer
grep -q "is still a card" "$LOG" && NAME=airpointer-base
mv "$DRAFT" "out/$NAME.mp4"

# The poster: the title card with the lid open, for a thumbnail or a README image.
"$FILM" stills "$CACHE/Film/work" 3.2 "$@" >/dev/null
mv "$CACHE/Film/work/t003.20.png" "out/$NAME-poster.png"

# The copy for the web: GitHub takes video attachments up to 10 MB on a free account.
# The same picture at the same size and rate, encoded in two passes to land under that
# with room to spare (a two-pass encode lands within a few percent of what it is asked for).
BYTES=$(stat -f %z "out/$NAME.mp4")
LIMIT="${AIRPOINTER_WEB_BYTES:-9400000}"
if [ "$BYTES" -le "$LIMIT" ] && [ "$SCALE" = 1 ]; then
  cp "out/$NAME.mp4" "out/$NAME-web.mp4"
else
  SECONDS_LONG=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "out/$NAME.mp4")
  HAS_SOUND=$(ffprobe -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 "out/$NAME.mp4" | head -1)
  SOUND_KBPS=0
  [ -n "$HAS_SOUND" ] && SOUND_KBPS=128
  # kilobits a second left for the picture, with 5% held back for the container.
  PICTURE_KBPS=$(awk -v b="$LIMIT" -v s="$SECONDS_LONG" -v a="$SOUND_KBPS" 'BEGIN { printf "%d", (b * 8 / s / 1000) * 0.95 - a }')
  PICTURE="-vf scale=1920:1080:flags=lanczos -c:v libx264 -preset slow -b:v ${PICTURE_KBPS}k -pix_fmt yuv420p -color_primaries bt709 -color_trc bt709 -colorspace bt709"
  ffmpeg -hide_banner -loglevel error -y -i "out/$NAME.mp4" $PICTURE -pass 1 -passlogfile "$CACHE/Film/work/pass" -an -f null /dev/null
  if [ -n "$HAS_SOUND" ]; then
    ffmpeg -hide_banner -loglevel error -y -i "out/$NAME.mp4" $PICTURE -pass 2 -passlogfile "$CACHE/Film/work/pass" -c:a aac -b:a 128k -movflags +faststart "out/$NAME-web.mp4"
  else
    ffmpeg -hide_banner -loglevel error -y -i "out/$NAME.mp4" $PICTURE -pass 2 -passlogfile "$CACHE/Film/work/pass" -an -movflags +faststart "out/$NAME-web.mp4"
  fi
fi
rm -rf "$CACHE/Film/work"

if [ "$(stat -f %z "out/$NAME-web.mp4")" -gt 10000000 ]; then
  echo "The web copy came out over 10 MB; GitHub may refuse it. Run again with AIRPOINTER_WEB_BYTES=8500000." >&2
fi

echo
for f in "out/$NAME.mp4" "out/$NAME-web.mp4" "out/$NAME-poster.png"; do
  printf "%-34s %6.1f MB\n" "$f" "$(stat -f %z "$f" | awk '{ print $1 / 1000000 }')"
done
