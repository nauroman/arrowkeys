#!/bin/bash
# Development builds use a stable Apple identity so macOS can recognize updates.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "${1:?Supply an output directory}"
out=$(cd "$1" && pwd)
mode=${2:---development}
case "$mode" in
    --development|--archive) identity=${MAC_APP_SIGN_IDENTITY:-Apple Development} ;;
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
version=1.0
build_number=${MAC_STORE_BUILD_NUMBER:-6}
mkdir -p "$contents/MacOS" "$contents/Resources" "$contents/Helpers"
cp "$repo/macos/Info.plist" "$contents/Info.plist"
cp "$repo/assets/ArrowKeys.icns" "$repo/assets/ArrowKeysMenuTemplate.svg" "$repo/LICENSE" "$contents/Resources/"
cp "$repo/packaging/mac-app-store/PrivacyInfo.xcprivacy" "$contents/Resources/"
plist=/usr/libexec/PlistBuddy
info="$contents/Info.plist"
"$plist" -c "Set :CFBundleIdentifier $id" -c 'Set :CFBundleName ArrowKeys Store' \
    -c 'Add :CFBundleDisplayName string ArrowKeys Store' -c "Set :CFBundleShortVersionString $version" \
    -c "Set :CFBundleVersion $build_number" -c 'Set :LSMinimumSystemVersion 15.2' \
    -c 'Add :CFBundleInfoDictionaryVersion string 6.0' -c 'Add :CFBundleDevelopmentRegion string en' \
    -c 'Add :ITSAppUsesNonExemptEncryption bool false' \
    -c 'Add :LSApplicationCategoryType string public.app-category.productivity' \
    -c 'Add :LSMultipleInstancesProhibited bool true' -c 'Add :CFBundleSupportedPlatforms array' \
    -c 'Add :CFBundleSupportedPlatforms:0 string MacOSX' \
    -c 'Set :NSAccessibilityUsageDescription ArrowKeys sends navigation arrows to the active app when you use its eight shortcuts.' "$info"
if [[ "$mode" == --archive || "$mode" == --distribution ]]; then
    sdk_version=$(xcrun --sdk macosx --show-sdk-version)
    sdk_build=$(xcrun --sdk macosx --show-sdk-build-version)
    xcode_version=$(xcodebuild -version)
    xcode_dtd=$(awk '/^Xcode / { split($2, v, "."); printf "%02d%d%d", v[1], v[2], v[3] }' <<< "$xcode_version")
    xcode_build=$(awk '/^Build version / { print $3 }' <<< "$xcode_version")
    "$plist" -c "Add :BuildMachineOSBuild string $(sw_vers -buildVersion)" \
        -c 'Add :DTCompiler string com.apple.compilers.llvm.clang.1_0' \
        -c 'Add :DTPlatformName string macosx' -c "Add :DTPlatformVersion string $sdk_version" \
        -c "Add :DTPlatformBuild string $sdk_build" -c "Add :DTSDKBuild string $sdk_build" \
        -c "Add :DTSDKName string macosx$sdk_version" -c "Add :DTXcode string $xcode_dtd" \
        -c "Add :DTXcodeBuild string $xcode_build" "$info"
fi
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
if [[ "$mode" == --archive ]]; then
    team=$(codesign -dv --verbose=4 "$app" 2>&1 | sed -n 's/^TeamIdentifier=//p')
    [[ -n "$team" && "$team" != 'not set' ]]
    archive="$stage/ArrowKeys.xcarchive"
    mkdir -p "$archive/Products/Applications"
    mv "$app" "$archive/Products/Applications/"
    archive_info="$archive/Info.plist"
    "$plist" -c 'Add :ArchiveVersion integer 2' -c 'Add :Name string ArrowKeys' \
        -c 'Add :SchemeName string ArrowKeys' -c 'Add :ApplicationProperties dict' \
        -c 'Add :ApplicationProperties:ApplicationPath string Applications/ArrowKeys Store.app' \
        -c "Add :ApplicationProperties:CFBundleIdentifier string $id" \
        -c "Add :ApplicationProperties:CFBundleShortVersionString string $version" \
        -c "Add :ApplicationProperties:CFBundleVersion string $build_number" \
        -c "Add :ApplicationProperties:Team string $team" "$archive_info"
    plutil -insert CreationDate -date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$archive_info"
    [[ ! -e "$out/ArrowKeys.xcarchive" ]] || { echo 'Choose an output directory without an existing archive.' >&2; exit 1; }
    mv "$archive" "$out/"
elif [[ "$mode" == --distribution ]]; then
    productbuild --component "$app" /Applications --sign "$MAC_INSTALLER_SIGN_IDENTITY" "$out/ArrowKeys-Mac-App-Store.pkg"
    pkgutil --check-signature "$out/ArrowKeys-Mac-App-Store.pkg"
else
    ditto -c -k --keepParent --sequesterRsrc "$app" "$out/ArrowKeys-Store-Mac.zip"
fi
