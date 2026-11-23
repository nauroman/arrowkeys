#!/bin/bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
xcrun clang -fobjc-arc -framework Cocoa -framework Carbon -framework ApplicationServices \
  "$repo/tests/macos-native.m" -o "$stage/test"
"$stage/test"
