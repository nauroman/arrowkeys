#!/bin/bash
# Notarize and staple a Developer ID package with an App Store Connect API key, given as
# ASC_KEY_PATH (.p8 file), ASC_KEY_ID and ASC_ISSUER_ID.
set -euo pipefail
pkg=$1
credentials=(--key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID")
result=$(mktemp)
trap 'rm -f "$result"' EXIT
xcrun notarytool submit "$pkg" "${credentials[@]}" --wait --timeout 30m --output-format json > "$result"
status=$(plutil -extract status raw "$result")
if [[ $status != Accepted ]]; then
  echo "Apple notarization finished with status $status" >&2
  xcrun notarytool log "$(plutil -extract id raw "$result")" "${credentials[@]}" >&2 || true
  exit 1
fi
xcrun stapler staple "$pkg"
xcrun stapler validate "$pkg"
