#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="$ROOT/build/GraphoMac.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
FRAMEWORKS="$CONTENTS/Frameworks"
RESOURCES="$CONTENTS/Resources"
EXECUTABLE="$ROOT/frontend-macos/.build/debug/GraphoMac"

if [ ! -x "$EXECUTABLE" ]; then
  echo "GraphoMac executable not found at $EXECUTABLE" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$MACOS" "$FRAMEWORKS" "$RESOURCES"

cp "$ROOT/frontend-macos/Info.plist" "$CONTENTS/Info.plist"
cp "$EXECUTABLE" "$MACOS/GraphoMac"
cp "$ROOT"/build/lib/libgrapho-core*.dylib "$FRAMEWORKS/"

chmod +x "$MACOS/GraphoMac"

echo "Created $APP"
