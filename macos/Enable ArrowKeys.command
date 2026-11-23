#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
umask 077
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/karabiner"
assets="$config_dir/assets/complex_modifications"
tempdir=$(mktemp -d "${TMPDIR:-/tmp}/arrowkeys.XXXXXXXX")
pending=''
cleanup() {
  if [[ -n "$pending" ]]; then rm -f "$pending"; fi
  rm -rf "$tempdir"
}
trap cleanup EXIT

mkdir -p "$assets"
pending=$(mktemp "$assets/.arrowkeys.XXXXXXXX")
cp arrowkeys.json "$pending"
mv -f "$pending" "$assets/nauroman-arrowkeys.json"
pending=''
config="$config_dir/karabiner.json"
manual_enable() {
  echo 'Open Karabiner-Elements → Complex Modifications → Add predefined rule → ArrowKeys → Enable.'
}
configure() {
  if [[ -L "$config" ]]; then manual_enable; return; fi
  if [[ -e "$config" ]]; then
    cp "$config" "$tempdir/original.json"
  else
    echo '{"profiles":[{"name":"Default profile","selected":true}]}' > "$tempdir/original.json"
  fi
  pending=$(mktemp "$config_dir/.arrowkeys-profile.XXXXXXXX")
  if ! /usr/bin/osascript -l JavaScript configure.js "$tempdir/original.json" arrowkeys.json > "$pending"; then
    manual_enable
    return
  fi
  if grep -qx unchanged "$pending"; then echo 'ArrowKeys is already enabled.'; return; fi
  if [[ -e "$config" ]]; then
    if ! cmp -s "$config" "$tempdir/original.json"; then manual_enable; return; fi
    backup=$(mktemp "$config_dir/karabiner.before-arrowkeys.XXXXXXXX")
    cp -p "$config" "$backup"
    echo "Saved the previous profile in $backup"
    mv -f "$pending" "$config"
  else
    # Publish a complete file only if Karabiner has not created its own meanwhile.
    if ! ln "$pending" "$config"; then manual_enable; return; fi
    rm "$pending"
  fi
  pending=''
  echo 'ArrowKeys is enabled in the selected profile.'
}
configure
if [[ $# == 0 ]]; then
  open -a Karabiner-Elements
  echo 'Complete any permission prompts in Karabiner-Elements. Then try Caps Lock + J in TextEdit.'
fi
