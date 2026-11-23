#!/bin/bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$1"
out=$(cd "$1" && pwd)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
app="$stage/payload/ArrowKeys.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$repo/macos/Info.plist" "$app/Contents/"
cp "$repo/LICENSE" "$app/Contents/Resources/"
cp "$repo/assets/ArrowKeys.icns" "$repo/assets/ArrowKeysMenuTemplate.svg" "$app/Contents/Resources/"
xcrun clang -arch arm64 -arch x86_64 -mmacosx-version-min=13.0 -fobjc-arc -Os \
  -framework Cocoa -framework Carbon -framework ApplicationServices -framework ServiceManagement -framework IOKit \
  "$repo/macos/ArrowKeys.m" -o "$app/Contents/MacOS/ArrowKeys"
codesign --force --sign - --identifier com.nauroman.ArrowKeys "$app"
mkdir "$stage/scripts"
install -m 755 "$repo/packaging/macos-postinstall" "$stage/scripts/postinstall"
pkgbuild --root "$stage/payload" --scripts "$stage/scripts" --install-location /Applications \
  --identifier com.nauroman.arrowkeys.native --version 1.1.4 "$stage/ArrowKeysApp.pkg"
cp -R "$repo/packaging/mac-resources" "$stage/resources"
sips -j "$repo/packaging/installer-background.js" "$repo/assets/ArrowKeys.png" --out "$stage/resources/ArrowKeys.png" >/dev/null
productbuild --distribution "$repo/packaging/macos-distribution.xml" --resources "$stage/resources" \
  --package-path "$stage" "$out/ArrowKeys-macOS.pkg"
