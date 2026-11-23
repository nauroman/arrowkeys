#!/bin/bash
set -euo pipefail
out=$1
mkdir -p "$out"
cd "$out"
curl -fsSL --retry 3 https://codeload.github.com/pqrs-org/Karabiner-Elements/tar.gz/refs/tags/v16.3.0 -o source.tgz
curl -fsSL --retry 3 https://codeload.github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/tar.gz/bdfcb459b2eaca8ccda680a73b0dc898f330f4bb -o headers.tgz
echo '93d38d8dc3d159707d878b5dba1535a9eeeb078f0be754d9313ed4ec4f31ed2b  source.tgz' | shasum -a 256 -c -
echo 'ced1b626e24041f7db0fe2da36bafe0ff40f385c7817e2aa42017f476b06ccfc  headers.tgz' | shasum -a 256 -c -
tar -xzf source.tgz
cd Karabiner-Elements-16.3.0
tar -xzf ../headers.tgz -C vendor/Karabiner-DriverKit-VirtualHIDDevice --strip-components=1
xcrun clang -w -c vendor/duktape-src/duktape.c -o ../duktape.o
xcrun clang -w -I vendor/duktape-src -c vendor/duktape-2.7.0/extras/console/duk_console.c -o ../console.o
xcrun clang++ -std=c++23 -O0 -w -Wno-missing-template-arg-list-after-template-kw \
  -I src/share -I vendor/Karabiner-DriverKit-VirtualHIDDevice/include -I vendor/vendor/include \
  -I vendor/duktape-src -I vendor/duktape-2.7.0/extras/console -I vendor/duktape-2.7.0/extras/module-node \
  tests/src/manipulator/src/overwrite_expected_results.cpp ../duktape.o ../console.o \
  -framework IOKit -framework CoreFoundation -framework CoreGraphics -o ../run-events
