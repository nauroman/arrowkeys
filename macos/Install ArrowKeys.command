#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
umask 077
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/karabiner"
assets="$config_dir/assets/complex_modifications"
cli='/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli'
tempdir=$(mktemp -d "${TMPDIR:-/tmp}/arrowkeys.XXXXXXXX")
mount="$tempdir/volume"
pending=''
cleanup() {
  if [[ -d "$mount" ]]; then hdiutil detach "$mount" -quiet || true; fi
  if [[ -n "$pending" ]]; then rm -f "$pending"; fi
  rm -rf "$tempdir"
}
trap cleanup EXIT

if [[ ${1:-} != --configure-only && ! -x "$cli" ]]; then
  major=$(sw_vers -productVersion | cut -d. -f1)
  if (( major < 13 )); then
    echo 'Install a compatible Karabiner-Elements version from https://karabiner-elements.pqrs.org/ and run this file again.'
    exit 1
  fi
  echo 'Downloading Karabiner-Elements 16.3.0 from its official release…'
  url='https://github.com/pqrs-org/Karabiner-Elements/releases/download/v16.3.0/Karabiner-Elements-16.3.0.dmg'
  curl --fail --location --silent --show-error --retry 2 --proto '=https' --proto-redir '=https' "$url" -o "$tempdir/karabiner.dmg"
  (cd "$tempdir" && echo '19cce7bed3d48a722242ca683bd1bae406b6a87fed520728d1c91dee175b75e4  karabiner.dmg' | shasum -a 256 -c -)
  hdiutil attach -readonly -nobrowse -mountpoint "$mount" "$tempdir/karabiner.dmg" >/dev/null
  packages=("$mount"/*.pkg)
  [[ ${#packages[@]} == 1 && -f "${packages[0]}" ]]
  /usr/sbin/spctl --assess --type install "${packages[0]}"
  if [[ ${1:-} == --non-interactive ]]; then
    sudo -n /usr/sbin/installer -pkg "${packages[0]}" -target /
  else
    /usr/bin/osascript - "${packages[0]}" <<'APPLESCRIPT'
on run argv
    do shell script "/usr/sbin/installer -pkg " & quoted form of (item 1 of argv) & " -target /" with administrator privileges
end run
APPLESCRIPT
  fi
  [[ -x "$cli" ]]
fi

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
