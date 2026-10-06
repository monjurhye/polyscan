#!/usr/bin/env bash
# Builds Leptonica + Tesseract as a static TesseractC.xcframework for iOS
# (device arm64, simulator arm64; set SIM_X86_64=1 to add an Intel simulator
# slice). Runs on macOS only (Codemagic).
#
# Only the C API (capi.h) is exposed, so Swift can import it directly.
# Leptonica is built without image codecs: the plugin hands Tesseract raw
# grayscale pixels, so no PNG/JPEG/TIFF libraries are needed.
#
# Usage: ios/scripts/build_tesseract.sh        (skips if the xcframework exists)
#        FORCE=1 ios/scripts/build_tesseract.sh

set -euo pipefail

TESSERACT_VERSION=5.5.3
LEPTONICA_VERSION=1.87.0
MIN_IOS=15.0

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../polyscan_ocr/TesseractC.xcframework"
WORK="${TESSERACT_WORK_DIR:-$HERE/../.tesseract-build}"
JOBS="$(sysctl -n hw.ncpu)"

if [[ -d "$OUT" && "${FORCE:-0}" != 1 ]]; then
  echo "TesseractC.xcframework already exists, skipping (FORCE=1 to rebuild)"
  exit 0
fi

command -v cmake >/dev/null || brew install cmake

mkdir -p "$WORK/src"
cd "$WORK/src"
[[ -d leptonica ]] || git clone --depth 1 --branch "$LEPTONICA_VERSION" https://github.com/DanBloomberg/leptonica.git
[[ -d tesseract ]] || git clone --depth 1 --branch "$TESSERACT_VERSION" https://github.com/tesseract-ocr/tesseract.git

# build_slice <name> <sdk> <arch>
build_slice() {
  local name=$1 sdk=$2 arch=$3
  local prefix="$WORK/install/$name"
  local common=(
    -DCMAKE_SYSTEM_NAME=iOS
    -DCMAKE_OSX_SYSROOT="$sdk"
    -DCMAKE_OSX_ARCHITECTURES="$arch"
    -DCMAKE_SYSTEM_PROCESSOR="$arch"
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_IOS"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="$prefix"
    -DCMAKE_PREFIX_PATH="$prefix"
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
    -DBUILD_SHARED_LIBS=OFF
  )

  echo "=== Leptonica ($name)"
  cmake -S "$WORK/src/leptonica" -B "$WORK/build/$name/leptonica" "${common[@]}" \
    -DSW_BUILD=OFF -DBUILD_PROG=OFF \
    -DENABLE_ZLIB=OFF -DENABLE_PNG=OFF -DENABLE_GIF=OFF -DENABLE_JPEG=OFF \
    -DENABLE_TIFF=OFF -DENABLE_WEBP=OFF -DENABLE_OPENJPEG=OFF
  cmake --build "$WORK/build/$name/leptonica" --config Release -j "$JOBS"
  cmake --install "$WORK/build/$name/leptonica" --config Release

  local lept_dir
  lept_dir="$(dirname "$(find "$prefix" -name 'LeptonicaConfig.cmake' | head -1)")"

  echo "=== Tesseract ($name)"
  cmake -S "$WORK/src/tesseract" -B "$WORK/build/$name/tesseract" "${common[@]}" \
    -DLeptonica_DIR="$lept_dir" \
    -DSW_BUILD=OFF -DBUILD_TRAINING_TOOLS=OFF -DBUILD_TESTS=OFF \
    -DGRAPHICS_DISABLED=ON -DDISABLED_LEGACY_ENGINE=ON -DENABLE_LTO=OFF \
    -DOPENMP_BUILD=OFF -DDISABLE_ARCHIVE=ON -DDISABLE_CURL=ON -DDISABLE_TIFF=ON \
    -DINSTALL_CONFIGS=OFF
  cmake --build "$WORK/build/$name/tesseract" --config Release --target libtesseract -j "$JOBS"

  local lept_lib tess_lib
  lept_lib="$(find "$prefix" -name 'libleptonica*.a' -o -name 'liblept*.a' | head -1)"
  tess_lib="$(find "$WORK/build/$name/tesseract" -name 'libtesseract*.a' | head -1)"
  echo "leptonica: $lept_lib"
  echo "tesseract: $tess_lib"
  libtool -static -o "$WORK/lib-$name.a" "$lept_lib" "$tess_lib"
}

build_slice device-arm64 iphoneos arm64
build_slice sim-arm64 iphonesimulator arm64
if [[ "${SIM_X86_64:-0}" == 1 ]]; then
  build_slice sim-x86_64 iphonesimulator x86_64
fi

# make_framework <dir> <static lib>
make_framework() {
  local fw="$1/TesseractC.framework"
  rm -rf "$fw"
  mkdir -p "$fw/Headers" "$fw/Modules"
  cp "$2" "$fw/TesseractC"
  cp "$WORK/src/tesseract/include/tesseract/capi.h" "$WORK/src/tesseract/include/tesseract/export.h" "$fw/Headers/"
  cat > "$fw/Headers/TesseractC.h" <<'EOF'
#include "export.h"
#include "capi.h"
EOF
  cat > "$fw/Modules/module.modulemap" <<'EOF'
framework module TesseractC {
  umbrella header "TesseractC.h"
  export *
  module * { export * }
  link "c++"
}
EOF
  cat > "$fw/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>TesseractC</string>
  <key>CFBundleIdentifier</key><string>com.pickixo.TesseractC</string>
  <key>CFBundleName</key><string>TesseractC</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>$TESSERACT_VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>MinimumOSVersion</key><string>$MIN_IOS</string>
</dict>
</plist>
EOF
}

mkdir -p "$WORK/fw/device" "$WORK/fw/sim"
if [[ -f "$WORK/lib-sim-x86_64.a" ]]; then
  lipo -create "$WORK/lib-sim-arm64.a" "$WORK/lib-sim-x86_64.a" -output "$WORK/lib-sim.a"
else
  cp "$WORK/lib-sim-arm64.a" "$WORK/lib-sim.a"
fi
make_framework "$WORK/fw/device" "$WORK/lib-device-arm64.a"
make_framework "$WORK/fw/sim" "$WORK/lib-sim.a"

rm -rf "$OUT"
xcodebuild -create-xcframework \
  -framework "$WORK/fw/device/TesseractC.framework" \
  -framework "$WORK/fw/sim/TesseractC.framework" \
  -output "$OUT"

echo "=== Done"
du -sh "$OUT"
lipo -info "$OUT"/*/TesseractC.framework/TesseractC
