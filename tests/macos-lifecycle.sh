#!/bin/bash
# Only install and remove system software on the disposable hosted runner.
set -euo pipefail
[[ ${GITHUB_ACTIONS:-} == true && ${RUNNER_ENVIRONMENT:-} == github-hosted ]]
app=/Applications/ArrowKeys.app
repo=$(cd "$(dirname "$0")/.." && pwd)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
snapshot_keyboard() {
  /usr/bin/hidutil property --get UserKeyMapping
  /usr/bin/defaults read com.apple.HIToolbox AppleEnabledInputSources || true
  /usr/bin/defaults -currentHost read -g | grep -A 12 'modifiermapping' || true
}
snapshot_keyboard > "$stage/keyboard-before"
pkgutil --expand "$1" "$stage/expanded"
welcome=$(find "$stage/expanded/Resources" -name 'welcome.rtf' -print -quit)
grep -Fq 'HYPERLINK "https://github.com/nauroman/arrowkeys"' "$welcome"
grep -Fq 'HYPERLINK "https://github.com/nauroman/arrowkeys/releases/latest"' "$welcome"
test ! -e "$app"
for cycle in 1 2; do
  sudo installer -pkg "$1" -target /
  codesign --verify --strict "$app"
  lipo "$app/Contents/MacOS/ArrowKeys" -verify_arch arm64 x86_64
  pkgutil --pkg-info com.nauroman.arrowkeys.native
  cmp "$repo/assets/ArrowKeys.icns" "$app/Contents/Resources/ArrowKeys.icns"
  cmp "$repo/assets/ArrowKeysMenuTemplate.svg" "$app/Contents/Resources/ArrowKeysMenuTemplate.svg"
  test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIconFile' "$app/Contents/Info.plist")" = ArrowKeys.icns
  test ! -e /Applications/Karabiner-Elements.app
  # Only the package starts the app. Require the signed-in user to own it.
  console_uid=$(/usr/bin/stat -f '%u' /dev/console)
  test "$console_uid" -ne 0
  for ((i=0; i<50; i++)); do
    pid=$(pgrep -u "$console_uid" -x ArrowKeys || true)
    [[ -n "$pid" ]] && break
    sleep 0.2
  done
  test -n "$pid"
  # Exercise the real menu-bar process while its bundle is removed from Applications.
  sleep 2
  sudo mv "$app" "$stage/removed-$cycle.app"
  for ((i=0; i<50; i++)); do
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
    sleep 0.2
  done
  if kill -0 "$pid" 2>/dev/null; then echo 'ArrowKeys survived bundle removal' >&2; exit 1; fi
  sudo rm -r "$stage/removed-$cycle.app"
  sudo pkgutil --forget com.nauroman.arrowkeys.native
  snapshot_keyboard > "$stage/keyboard-after"
  diff -u "$stage/keyboard-before" "$stage/keyboard-after"
done
