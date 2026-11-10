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

