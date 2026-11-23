#!/bin/bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
app="$stage/ArrowKeys.app/Contents"
mkdir -p "$app/MacOS" "$app/Resources"
cp "$repo/macos/Info.plist" "$app/"
cp "$repo/assets/ArrowKeysMenuTemplate.svg" "$app/Resources/"
xcrun clang -fobjc-arc -framework Cocoa -framework Carbon -framework ApplicationServices -framework IOKit \
  "$repo/tests/macos-native.m" -o "$app/MacOS/ArrowKeys"
"$app/MacOS/ArrowKeys"
