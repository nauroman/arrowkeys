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
support='payload/Library/Application Support/ArrowKeys'
mkdir -p "$support" payload/Applications
cp "$repo"/macos/{arrowkeys.json,configure.js,"Enable ArrowKeys.command"} "$support/"
cp "$repo/LICENSE" "$support/"
chmod 755 "$support/Enable ArrowKeys.command"
chmod 644 "$support"/{arrowkeys.json,configure.js,LICENSE}
install -m 755 "$repo/macos/Uninstall ArrowKeys.command" "payload/Applications/Uninstall ArrowKeys.command"
mkdir scripts
install -m 755 "$repo/packaging/macos-postinstall" scripts/postinstall
install -m 644 "$repo/assets/ArrowKeys.icns" scripts/ArrowKeys.icns
cp -R "$repo/packaging/mac-resources" resources
sips -Z 128 "$repo/assets/ArrowKeys.png" --out resources/ArrowKeys.png >/dev/null
pkgbuild --root payload --install-location '/' \
  --ownership recommended --identifier com.nauroman.arrowkeys.profile --version 1.0.2 \
  --scripts scripts ArrowKeysProfile.pkg
productbuild --distribution "$repo/packaging/macos-distribution.xml" --resources resources \
  --package-path "$stage" "$out/ArrowKeys-macOS.pkg"
