#!/bin/bash
# Only install and remove system software on the disposable hosted runner.
set -euo pipefail
[[ ${GITHUB_ACTIONS:-} == true && ${RUNNER_ENVIRONMENT:-} == github-hosted ]]
app=/Applications/ArrowKeys.app
test ! -e "$app"
for cycle in 1 2; do
  sudo installer -pkg "$1" -target /
  codesign --verify --strict "$app"
  lipo "$app/Contents/MacOS/ArrowKeys" -verify_arch arm64 x86_64
  pkgutil --pkg-info com.nauroman.arrowkeys.native
  test ! -e /Applications/Karabiner-Elements.app
  sudo rm -r "$app"
  sudo pkgutil --forget com.nauroman.arrowkeys.native
done
