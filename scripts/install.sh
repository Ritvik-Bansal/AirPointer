#!/bin/sh
# Builds AirPointer, puts it in /Applications and opens it.
set -e
cd "$(dirname "$0")/.."
APP=$(./scripts/build.sh | tail -1)
[ -d "$APP" ] || { echo "$APP" >&2; exit 1; }
pkill -x AirPointer 2>/dev/null || true
sleep 0.5
rm -rf /Applications/AirPointer.app
cp -R "$APP" /Applications/AirPointer.app
echo "Installed /Applications/AirPointer.app"
open /Applications/AirPointer.app
