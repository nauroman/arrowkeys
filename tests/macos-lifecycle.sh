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
# A relocatable bundle would update another ArrowKeys copy instead of /Applications.
test "$(xmllint --xpath 'count(//relocate/bundle)' "$stage/expanded/ArrowKeysApp.pkg/PackageInfo")" = 0
if [[ ${MAC_EXPECT_SIGNED:-} == 1 ]]; then
  # Release packages carry a Developer ID Installer signature and a stapled notarization ticket.
  [[ $(pkgutil --check-signature "$1") == *'Developer ID Installer: '*'(B7UFH23G3L)'* ]]
  xcrun stapler validate "$1"
  [[ $(spctl --assess --type install -vv "$1" 2>&1) == *'source=Notarized Developer ID'* ]]
fi
test ! -e "$app"
for cycle in 1 2; do
  sudo installer -pkg "$1" -target /
  codesign --verify --strict "$app"
  # The system Accessibility alert stays open after access is granted, so only the app's guide may ask.
  prompt_refs=$(nm -u "$app/Contents/MacOS/ArrowKeys" | grep -F kAXTrustedCheckOptionPrompt || true)
  [[ -z "$prompt_refs" ]]
  lipo "$app/Contents/MacOS/ArrowKeys" -verify_arch arm64 x86_64
  if [[ ${MAC_EXPECT_SIGNED:-} == 1 ]]; then
    # The team requirement lets macOS keep Accessibility access across updates.
    codesign --verify --strict -R='anchor apple generic and certificate leaf[subject.OU] = "B7UFH23G3L"' "$app"
    [[ $(codesign -dv "$app" 2>&1) == *'(runtime)'* ]]
  fi
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
  # The app records setup after Service Management accepts the registration.
  for ((i=0; i<50; i++)); do
    login_configured=$(defaults read com.nauroman.ArrowKeys OpenAtLoginConfigured 2>/dev/null || true)
    [[ "$login_configured" == 1 ]] && break
    sleep 0.2
  done
  if [[ "$login_configured" != 1 ]]; then
    echo 'ArrowKeys did not finish configuring Open at Login' >&2
    /usr/bin/log show --last 2m --info --predicate 'process == "ArrowKeys" OR eventMessage CONTAINS[c] "com.nauroman.ArrowKeys"' | tail -100
    exit 1
  fi
  sudo /usr/bin/sfltool dumpbtm > "$stage/login-items"
  if ! grep -Fqi 'ArrowKeys' "$stage/login-items"; then
    echo 'ArrowKeys was absent from the macOS background task database' >&2
    exit 1
  fi
  if [[ $cycle == 1 ]]; then
    # Without access, a new ad hoc build clears the entry an earlier build left switched on,
    # then offers its guide once after giving macOS a moment to confirm existing access.
    build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist")
    for ((i=0; i<50; i++)); do
      shown=$(defaults read com.nauroman.ArrowKeys AccessibilitySetupShownForBuild 2>/dev/null || true)
      [[ "$shown" == "$build" ]] && break
      sleep 0.2
    done
    test "$shown" = "$build"
    resets=$(/usr/bin/log show --last 2m --predicate 'process == "tccutil"' | grep -Fc TCCResetInternal || true)
    (( resets > 0 ))
  fi
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
