#!/bin/bash
# This test installs and removes system software on a disposable GitHub-hosted Mac.
set -euo pipefail
[[ ${GITHUB_ACTIONS:-} == true && ${RUNNER_ENVIRONMENT:-} == github-hosted ]]
pkg=$1
repo=$(cd "$(dirname "$0")/.." && pwd)
stage=$(mktemp -d)
cli='/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli'
support='/Library/Application Support/ArrowKeys'
uninstall='/Applications/Uninstall ArrowKeys.command'
config="$HOME/.config/karabiner/karabiner.json"
test ! -e "$cli"
test ! -e "$support"
test ! -e "$config"
[[ "$(stat -f %Su /dev/console)" == "$(id -un)" ]]
mkdir -p "$(dirname "$config")"
echo '{"profiles":[{"name":"Work","selected":true,"complex_modifications":{"rules":[{"description":"Test F18 shortcut","manipulators":[{"type":"basic","from":{"key_code":"f18"},"to":[{"key_code":"f19"}]}]}]}},{"name":"Other"}]}' > "$config"
cp "$config" "$stage/initial.json"
bash "$repo/tests/build-event-probe.sh" "$stage/engine"
xcrun clang -fobjc-arc -framework Cocoa "$repo/tests/macos-cursor.m" -o "$stage/cursor"
for cycle in 1 2; do
  sudo installer -pkg "$pkg" -target /
  # The vendor's own postinstall sets a Finder icon. Verify all sealed files on a
  # copy without that mutable Finder metadata, keeping the installed app intact.
  ditto --norsrc --noextattr /Applications/Karabiner-Elements.app "$stage/Karabiner-$cycle.app"
  codesign --verify --strict "$stage/Karabiner-$cycle.app"
  pkgutil --pkg-info com.nauroman.arrowkeys.profile
  asset="$(dirname "$config")/assets/complex_modifications/nauroman-arrowkeys.json"
  "$cli" --lint-complex-modifications "$asset"
  test -x "$uninstall"
  for command in "$uninstall" "$support/Enable ArrowKeys.command"; do
    xattr -p com.apple.ResourceFork "$command" >/dev/null
  done
  installer -showChoicesXML -pkg "$pkg" -target / > "$stage/choices.plist"
  python3 -c 'import plistlib,sys; items=plistlib.load(open(sys.argv[1],"rb"))[0]["childItems"]; choices={c["choiceIdentifier"]:c["choiceIsSelected"] for c in items}; assert choices=={"karabiner":False,"driver":False,"profile":True}, choices' "$stage/choices.plist"
  mkdir "$stage/on-$cycle" "$stage/off-$cycle"
  (cd "$stage/on-$cycle"; python3 "$repo/tests/macos-events.py" "$stage/engine/run-events" "$config"; "$stage/cursor" cursor-events.json)
  "$uninstall" --yes
  test ! -e "$support"
  test ! -e "$uninstall"
  test ! -e "$asset"
  if pkgutil --pkg-info com.nauroman.arrowkeys.profile; then exit 1; fi
  python3 -c 'import json,sys; assert json.load(open(sys.argv[1])) == json.load(open(sys.argv[2]))' "$config" "$stage/initial.json"
  (cd "$stage/off-$cycle"; python3 "$repo/tests/macos-events.py" "$stage/engine/run-events" "$config" removed)
  # Shared Karabiner remains usable until the user requests its own uninstaller.
  test -x "$cli"
  sudo bash '/Library/Application Support/org.pqrs/Karabiner-Elements/uninstall.sh'
  test ! -e "$cli"
  test ! -e /Applications/Karabiner-Elements.app
  test ! -e /Applications/.Karabiner-VirtualHIDDevice-Manager.app
  echo "Passed macOS installation, real AppKit cursor checks, uninstall and shared dependency removal (cycle $cycle)."
done
