#!/bin/bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/../.." && pwd)
src="$repo/tests/macos-store"
out=$(cd "${1:?Supply the directory containing ArrowKeys-Store-Mac.zip}" && pwd)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
ditto -x -k "$out/ArrowKeys-Store-Mac.zip" "$stage"
app="$stage/ArrowKeys Store.app"
codesign --verify --strict "$app"
codesign -d --entitlements - --xml "$app" > "$stage/signed.plist"
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$stage/signed.plist")" = true
cmp "$app/Contents/Resources/ArrowKeys.icns" "$repo/assets/ArrowKeys.icns"
cmp "$app/Contents/Resources/ArrowKeysMenuTemplate.svg" "$repo/assets/ArrowKeysMenuTemplate.svg"
if nm -um "$app/Contents/MacOS/ArrowKeys" | grep -E '_CGEventTapCreate|_AXIsProcessTrusted|_IOHIDManagerRegisterInput'; then
    echo 'Unexpected keyboard-monitoring API in the Store edition.' >&2; exit 1
fi
kit="$stage/ArrowKeys MacBook Check"
mkdir "$kit"
xcrun clang -arch arm64 -arch x86_64 -mmacosx-version-min=15.2 -fobjc-arc \
    -framework Cocoa -framework Carbon -framework IOKit -framework Security -framework ApplicationServices \
    "$src/StoreChecks.m" -o "$kit/StoreChecks"
codesign --force --sign - "$kit/StoreChecks"
"$kit/StoreChecks" --recovery
# A known pair with eight movements must pass. A wrong shortcut must fail.
src_fixture="$src/editor-fixture.txt"
echo 'Scoring self-test with generated documents (no keyboard input).'
printf '%s\n' 'alpha bravo charlie delta' '5alp10ha 4bravo charlie d7elta' '86alph2a3 bravo charlie delta' > "$stage/marked.txt"
"$kit/StoreChecks" --compare-editors "$stage/marked.txt" "$stage/marked.txt" "$src_fixture"
sed 's/d7elta/de7lta/' "$stage/marked.txt" > "$stage/wrong.txt"
if "$kit/StoreChecks" --compare-editors "$stage/marked.txt" "$stage/wrong.txt" "$src_fixture" >/dev/null; then
    echo 'Failed to detect a wrong physical-key result.' >&2; exit 1
fi
cp "$src_fixture" "$kit/editor-fixture.txt"
cp "$out/ArrowKeys-Store-Mac.zip" "$src/browser.html" "$src/Check on MacBook.command" "$kit/"
chmod 755 "$kit/Check on MacBook.command"
ditto -c -k --keepParent --sequesterRsrc "$kit" "$out/ArrowKeys-MacBook-Check.zip"
[[ ${2:-} == --hosted ]] || exit 0
[[ ${GITHUB_ACTIONS:-} == true && ${RUNNER_ENVIRONMENT:-} == github-hosted ]]
# Exercise the actual production bundle's removal watcher while the first-run panel is open.
# The clean runner has not consented, so the app must leave its keyboard assignment alone.
hidutil property --get UserKeyMapping > "$stage/before"
open -g -n "$app"
for ((i=0;i<40;i++)); do "$kit/StoreChecks" --store-running && break; sleep 0.25; done
"$kit/StoreChecks" --store-running
sleep 1
mv "$app" "$stage/Removed.app"
for ((i=0;i<40;i++)); do "$kit/StoreChecks" --store-running || break; sleep 0.25; done
if "$kit/StoreChecks" --store-running; then echo 'Production app remained running after removal.' >&2; exit 1; fi
hidutil property --get UserKeyMapping > "$stage/after"
cmp "$stage/before" "$stage/after"
receiver="$stage/Registration Check.app"
mkdir -p "$receiver/Contents/MacOS"
cp "$stage/Removed.app/Contents/Info.plist" "$receiver/Contents/"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.nauroman.ArrowKeys.Store.RegistrationCheck' \
    -c 'Set :CFBundleExecutable StoreChecks' "$receiver/Contents/Info.plist"
cp "$kit/StoreChecks" "$receiver/Contents/MacOS/"
codesign --force --sign - --entitlements "$repo/packaging/mac-app-store/ArrowKeys.entitlements" "$receiver"
check_delivery() {
    local target=$1 fixture=$2 log="$stage/$1.log"
    open -b "$target" "$fixture"
    open -g -n --stdout "$log" --stderr "$log.err" "$receiver" --args --receive
    for ((i=0;i<60;i++)); do grep -q READY "$log" 2>/dev/null && break; sleep 0.25; done
    if ! grep -q READY "$log"; then cat "$log.err" >&2; exit 1; fi
    "$kit/StoreChecks" --drive "$target"
    for ((i=0;i<60;i++)); do grep -q released= "$log" && break; sleep 0.25; done
    echo "Shortcut registration with $target in front"
    cat "$log"
    grep -q 'pressed=0xff released=0xff' "$log"
}
cp "$src_fixture" "$stage/TextEdit.txt"
cp "$src_fixture" "$stage/Xcode.txt"
check_delivery com.apple.TextEdit "$stage/TextEdit.txt"
check_delivery com.apple.Safari "$src/browser.html"
check_delivery com.apple.dt.Xcode "$stage/Xcode.txt"
log="$stage/live-removal.log"
open -g -n --stdout "$log" --stderr "$log.err" "$receiver" --args --live-removal
for ((i=0;i<60;i++)); do grep -Eq 'APPLIED:|NO_KEYBOARD:|MAPPING_UNAVAILABLE:' "$log" 2>/dev/null && break; sleep 0.25; done
if grep -q '^APPLIED:' "$log"; then
    mv "$receiver" "$stage/Removed Keyboard Check.app"
    for ((i=0;i<60;i++)); do grep -q '^RESTORED:' "$log" && break; sleep 0.25; done
    cat "$log"
    grep -q '^RESTORED:' "$log"
elif grep -Eq '^NO_KEYBOARD:|^MAPPING_UNAVAILABLE:.*Baseline restored: yes' "$log"; then
    cat "$log"
    echo 'Live device assignment requires a physical acceptance run.'
else
    cat "$log" "$log.err" >&2; exit 1
fi
echo 'Passed sandbox shortcut delivery and removal before consent. Physical Caps Lock acceptance is a separate MacBook check.'
