#!/bin/bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$1"
out=$(cd "$1" && pwd)
stage=$(mktemp -d)
mount="$stage/volume"
cleanup() {
  if [[ -d "$mount" ]]; then hdiutil detach -quiet "$mount" || true; fi
  rm -rf "$stage"
}
trap cleanup EXIT
cd "$stage"
url='https://github.com/pqrs-org/Karabiner-Elements/releases/download/v16.3.0/Karabiner-Elements-16.3.0.dmg'
curl --fail --location --silent --show-error --retry 2 --proto '=https' --proto-redir '=https' "$url" -o karabiner.dmg
echo '19cce7bed3d48a722242ca683bd1bae406b6a87fed520728d1c91dee175b75e4  karabiner.dmg' | shasum -a 256 -c -
hdiutil attach -readonly -nobrowse -mountpoint "$mount" karabiner.dmg >/dev/null
vendor="$mount/Karabiner-Elements.pkg"
spctl --assess --type install -vv "$vendor"
pkgutil --check-signature "$vendor" | grep -F 'Developer ID Installer: Fumihiko Takayama (G43BCU2T37)'

# Keep the vendor's component payloads and compressed installer scripts byte-for-byte.
mkdir components
(cd components && xar -xf "$vendor")
for component in Installer.pkg Karabiner-DriverKit-VirtualHIDDevice.pkg; do
  (cd "components/$component" && xar --compression none -cf "$stage/$component" Bom PackageInfo Payload Scripts)
done
mkdir payload
cp "$repo"/macos/{arrowkeys.json,configure.js,"Enable ArrowKeys.command"} payload/
cp "$repo/LICENSE" payload/
chmod 755 "payload/Enable ArrowKeys.command"
chmod 644 payload/{arrowkeys.json,configure.js,LICENSE}
mkdir scripts
install -m 755 "$repo/packaging/macos-postinstall" scripts/postinstall
pkgbuild --root payload --install-location '/Library/Application Support/ArrowKeys' \
  --ownership recommended --identifier com.nauroman.arrowkeys.profile --version 1.0.1 \
  --scripts scripts ArrowKeysProfile.pkg
productbuild --distribution "$repo/packaging/macos-distribution.xml" --resources "$repo/packaging/mac-resources" \
  --package-path "$stage" "$out/ArrowKeys-macOS.pkg"
