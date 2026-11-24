#!/bin/bash
# Physical acceptance test. This helper only reads the fixture files and keyboard assignments.
set -eu
cd "$(dirname "$0")"
kit=$PWD
checker="$kit/StoreChecks"
if "$checker" --github-running || "$checker" --store-running; then
    echo 'Choose Quit ArrowKeys in each running edition, then open this check again.'
    exit 1
fi
report=$(mktemp -d "$HOME/ArrowKeys-Check.XXXXXX")
run=${report##*.}
exec > >(tee "$report/Results.txt") 2>&1
printf 'MacBook check %s. Results folder: %s\n' "$run" "$report"
sw_vers
sysctl -n hw.model
"$checker" --keyboard-state > "$report/before.json" || { echo 'No keyboard available for the baseline.'; exit 1; }
mkdir -p "$HOME/Applications"
testdir=$(mktemp -d "$HOME/Applications/ArrowKeys Check.XXXXXX")
ditto -x -k "$kit/ArrowKeys-Store-Mac.zip" "$testdir"
app="$testdir/ArrowKeys Store.app"
open "$app"
echo 'Click Enable Navigation and approve cursor control in System Settings if asked.'
echo 'For this temporary copy you can uncheck Open at Login. Wait for Navigation active in its menu.'
read -r -p 'Press Return here when ready. '
"$checker" --store-running || { echo 'The Store app is not running.'; exit 1; }
"$checker" --keyboard-state > "$report/active.json"
passed=true
if ! "$checker" --check-active "$report/before.json" "$report/active.json"; then
    echo 'The expected temporary Caps Lock assignment could not be verified.'
    passed=false
fi
exercise_editor() {
    local editor=$1 kind file fixture="$kit/editor-fixture.txt" extension=txt
    if [[ $editor == 'Script Editor' ]]; then
        extension=applescript
        fixture="$report/Script Editor-original.applescript"
        sed 's/^alpha/-- ha/' "$kit/editor-fixture.txt" > "$fixture"
    fi
    printf '\nChecking %s. Type each digit AFTER releasing all keys of the preceding shortcut.\n' "$editor"
    for kind in reference caps; do
        file="$report/$editor-$kind.$extension"
        cp "$fixture" "$file"
        echo 'At the start press Command+Up, Down, Right, Right, Right, then type 0.'
        if [[ $kind == reference ]]; then
            echo 'Ordinary keys: Left 1, Down 2, Right 3, Up 4, Command+Left 5, Command+Right 6, Option+Left 7, Option+Right 8.'
        else
            echo 'Physical Caps Lock chords: Caps+J 1, Caps+K 2, Caps+L 3, Caps+I 4, Caps+U 5, Caps+O 6, Caps+H 7, Caps+semicolon 8.'
        fi
        echo 'Save this file with Command+S, then return to this Terminal window.'
        open -a "$editor" "$file"
        read -r -p 'Press Return after saving. '
    done
    "$checker" --compare-editors "$report/$editor-reference.$extension" "$report/$editor-caps.$extension" "$fixture" || passed=false
}
exercise_editor TextEdit
printf '\nChecking Safari. Press Start check and follow each prompt. Save results to Downloads.\n'
# mktemp above produces an alphanumeric run ID. The URL resolves inside this copy of the kit.
cp "$kit/browser.html" "$report/Safari-$run.html"
open -a Safari "$report/Safari-$run.html"
read -r -p 'Press Return when Safari has saved the report. '
safari="$HOME/Downloads/ArrowKeys-Safari-$run.json"
if [[ -f "$safari" ]]; then
    cp "$safari" "$report/Safari.json"
    "$checker" --check-safari "$report/Safari.json" "$run" || passed=false
else
    echo "Missing Safari report: $safari"
    passed=false
fi
editor=${ARROWKEYS_TEST_EDITOR:-}
if [[ -z $editor ]]; then
    for candidate in Xcode 'Visual Studio Code' Cursor BBEdit 'Script Editor'; do
        if open -Ra "$candidate" >/dev/null 2>&1; then editor=$candidate; break; fi
    done
fi
if [[ -n $editor ]]; then exercise_editor "$editor"; else echo 'No code editor found.'; passed=false; fi
printf '\nIn Finder, move the highlighted test copy of ArrowKeys Store.app to Trash.\n'
echo 'If Finder asks you to quit, choose Quit ArrowKeys from its menu and try again.'
open -R "$app"
read -r -p 'Press Return after moving the test copy to Trash. '
for ((i=0; i<40; i++)); do "$checker" --store-running || break; sleep 0.25; done
if [[ -e "$app" ]] || "$checker" --store-running; then echo 'Test app is still installed or running.'; passed=false; fi
"$checker" --keyboard-state > "$report/after.json"
if cmp -s "$report/before.json" "$report/after.json"; then
    echo 'Keyboard assignments after removal match the original snapshot.'
else
    echo 'Keyboard assignments changed across removal.'; passed=false
fi
printf 'zz' > "$report/After removal.txt"
echo 'In TextEdit, press Command+Down. Tap Caps Lock, type a, tap Caps Lock again, type a, then save.'
open -a TextEdit "$report/After removal.txt"
read -r -p 'Press Return after saving. '
case $(cat "$report/After removal.txt") in
    zzAa|zzaA) echo 'Physical Caps Lock toggled the letter case twice.' ;;
    *) echo 'Physical uppercase check failed. Two lowercase keystrokes should alternate case.'; passed=false ;;
esac
if [[ $passed == true ]]; then echo 'PASS: 24 shortcut comparisons and Caps Lock after removal.'
else echo 'INCOMPLETE OR FAILED. See the comparisons above.'; fi
open -R "$report/Results.txt"
[[ $passed == true ]]
