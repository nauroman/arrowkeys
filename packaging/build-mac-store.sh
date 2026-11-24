#!/bin/bash
# Development builds use a stable Apple identity so macOS can recognize updates.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "${1:?Supply an output directory}"
out=$(cd "$1" && pwd)
mode=${2:---development}
case "$mode" in
    --development) identity=${MAC_APP_SIGN_IDENTITY:-Apple Development} ;;
    --distribution) identity=${MAC_APP_SIGN_IDENTITY:?Supply an Apple Distribution signing identity} ;;
    --ad-hoc) identity=- ;;
    *) echo "Unknown build mode: $mode" >&2; exit 2 ;;
esac
if [[ "$mode" != --ad-hoc && "$identity" == - ]]; then
    echo 'Updates need an Apple signing identity. Use --ad-hoc only for disposable test builds.' >&2
    exit 2
fi
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
app="$stage/ArrowKeys Store.app"
contents="$app/Contents"
id=com.nauroman.ArrowKeys.Store
mkdir -p "$contents/MacOS" "$contents/Resources" "$contents/Helpers"
cp "$repo/macos/Info.plist" "$contents/Info.plist"
cp "$repo/assets/ArrowKeys.icns" "$repo/assets/ArrowKeysMenuTemplate.svg" "$repo/LICENSE" "$contents/Resources/"
plist=/usr/libexec/PlistBuddy
info="$contents/Info.plist"
"$plist" -c "Set :CFBundleIdentifier $id" -c 'Set :CFBundleName ArrowKeys Store' \
    -c 'Add :CFBundleDisplayName string ArrowKeys Store' -c 'Set :CFBundleShortVersionString 1.0' \
    -c "Set :CFBundleVersion ${MAC_STORE_BUILD_NUMBER:-4}" -c 'Set :LSMinimumSystemVersion 15.2' \
    -c 'Add :LSApplicationCategoryType string public.app-category.productivity' \
    -c 'Add :LSMultipleInstancesProhibited bool true' -c 'Add :CFBundleSupportedPlatforms array' \
    -c 'Add :CFBundleSupportedPlatforms:0 string MacOSX' \
    -c 'Set :NSAccessibilityUsageDescription ArrowKeys sends navigation arrows to the active app when you use its eight shortcuts.' "$info"
xcrun --sdk macosx clang -arch arm64 -arch x86_64 -mmacosx-version-min=15.2 -fobjc-arc -Os \
    -Wall -Wextra -Wno-unused-parameter -Werror=implicit-function-declaration \
    -framework Cocoa -framework Carbon -framework ApplicationServices -framework ServiceManagement -framework IOKit \
    "$repo/macos/StoreApp.m" -o "$contents/MacOS/ArrowKeys"
xcrun --sdk macosx clang -arch arm64 -arch x86_64 -mmacosx-version-min=15.2 -fobjc-arc -Os \
    -framework Cocoa "$repo/macos/SetupRelaunch.m" -o "$contents/Helpers/SetupRelaunch"
entitlements="$stage/Store.entitlements"
cp "$repo/packaging/mac-app-store/ArrowKeys.entitlements" "$entitlements"
if [[ "$mode" == --distribution ]]; then
    : "${MAC_INSTALLER_SIGN_IDENTITY:?Supply a Mac Installer Distribution identity}"
    : "${MAC_APP_STORE_PROFILE:?Supply the Mac App Store provisioning profile}"
    security cms -D -i "$MAC_APP_STORE_PROFILE" > "$stage/profile.plist"
    team=$("$plist" -c 'Print :TeamIdentifier:0' "$stage/profile.plist")
    prefix=$("$plist" -c 'Print :ApplicationIdentifierPrefix:0' "$stage/profile.plist")
    profile_id=$("$plist" -c 'Print :Entitlements:com.apple.application-identifier' "$stage/profile.plist")
    [[ "$profile_id" == "$prefix.$id" ]] || { echo "Profile does not match $id" >&2; exit 1; }
    "$plist" -c "Add :com.apple.application-identifier string $profile_id" \
        -c "Add :com.apple.developer.team-identifier string $team" "$entitlements"
    cp "$MAC_APP_STORE_PROFILE" "$contents/embedded.provisionprofile"
fi
codesign --force --options runtime --sign "$identity" --identifier "$id.SetupRelaunch" \
    --entitlements "$repo/packaging/mac-app-store/Relaunch.entitlements" "$contents/Helpers/SetupRelaunch"
codesign --force --options runtime --sign "$identity" --entitlements "$entitlements" "$app"
codesign --verify --strict --verbose=2 "$app"
if [[ "$mode" != --ad-hoc ]]; then
    codesign --verify --strict -R='anchor apple generic' "$app"
fi
architectures=" $(xcrun lipo -archs "$contents/MacOS/ArrowKeys") "
[[ "$architectures" == *" arm64 "* && "$architectures" == *" x86_64 "* ]]
if [[ "$mode" == --distribution ]]; then
    productbuild --component "$app" /Applications --sign "$MAC_INSTALLER_SIGN_IDENTITY" "$out/ArrowKeys-Mac-App-Store.pkg"
    pkgutil --check-signature "$out/ArrowKeys-Mac-App-Store.pkg"
else
    ditto -c -k --keepParent --sequesterRsrc "$app" "$out/ArrowKeys-Store-Mac.zip"
fi
