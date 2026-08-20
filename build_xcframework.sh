#!/bin/bash
set -e

# --- Configuration ---
PROJECT_DIR=$(cd "$(dirname "$0")" && pwd)
SOURCE_DIR="$PROJECT_DIR/wrapper"
QWEN_HEADER="$PROJECT_DIR/qwentts.cpp/src/qwen.h"
BUILD_DIR="$PROJECT_DIR/build_xcframework"
OUTPUT_XCFRAMEWORK="$PROJECT_DIR/Qwen3TTSLib.xcframework"

echo "=== Building Qwen3 TTS XCFramework ==="

mkdir -p "$BUILD_DIR"

# -g keeps DWARF debug info alongside -O3/-DNDEBUG so dsymutil below has
# something real to extract, instead of producing an empty dSYM that only
# satisfies the UUID check without any actual symbolication value.
RELEASE_WITH_DEBUG="-O3 -DNDEBUG -g"

# Apple-only cmake flags shared by all three slices below:
# - BUILD_SHARED_LIBS=OFF statically links ggml (and its cpu/metal/blas
#   backends) into libqwen3.dylib itself, so the xcframework has nothing
#   to sideload at runtime.
# - GGML_OPENMP=OFF avoids linking against a host Homebrew libomp that
#   would not resolve (or would be the wrong slice) once cross-compiled.
COMMON_FLAGS=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CXX_FLAGS_RELEASE="$RELEASE_WITH_DEBUG"
    -DCMAKE_C_FLAGS_RELEASE="$RELEASE_WITH_DEBUG"
    -DBUILD_SHARED_LIBS=OFF
    -DGGML_OPENMP=OFF
)

# 1. macOS (Universal: arm64 and x86_64)
echo "--- Building macOS Universal ---"
mkdir -p "$BUILD_DIR/mac"
cd "$BUILD_DIR/mac"
cmake "$SOURCE_DIR" -DCMAKE_SYSTEM_NAME=Darwin \
            -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
            "${COMMON_FLAGS[@]}"
cmake --build . --config Release --target qwen3

# 2. iOS (arm64)
echo "--- Building iOS ---"
mkdir -p "$BUILD_DIR/ios"
cd "$BUILD_DIR/ios"
cmake "$SOURCE_DIR" -DCMAKE_SYSTEM_NAME=iOS \
            -DCMAKE_OSX_SYSROOT=iphoneos \
            -DCMAKE_OSX_ARCHITECTURES=arm64 \
            "${COMMON_FLAGS[@]}"
cmake --build . --config Release --target qwen3

# 3. iOS Simulator (Universal: arm64 and x86_64)
echo "--- Building iOS Simulator Universal ---"
mkdir -p "$BUILD_DIR/ios_sim"
cd "$BUILD_DIR/ios_sim"
cmake "$SOURCE_DIR" -DCMAKE_SYSTEM_NAME=iOS \
            -DCMAKE_OSX_SYSROOT=iphonesimulator \
            -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
            "${COMMON_FLAGS[@]}"
cmake --build . --config Release --target qwen3

# --- Create XCFramework ---
echo "--- Creating XCFramework ---"
cd "$PROJECT_DIR"
rm -rf "$OUTPUT_XCFRAMEWORK"

# Prepare headers directory. qwen.h is the whole public ABI (see its own
# header comment) — pipeline-tts.h / pipeline-codec.h stay internal.
mkdir -p "$BUILD_DIR/include"
cp "$QWEN_HEADER" "$BUILD_DIR/include/"

MAC_DYLIB="$BUILD_DIR/mac/bin/libqwen3.dylib"
IOS_DYLIB="$BUILD_DIR/ios/bin/libqwen3.dylib"
IOS_SIM_DYLIB="$BUILD_DIR/ios_sim/bin/libqwen3.dylib"

# Fix @rpath install names so consumers don't pick up this machine's
# absolute build path.
for LIB in "$MAC_DYLIB" "$IOS_DYLIB" "$IOS_SIM_DYLIB"; do
    chmod +w "$LIB"
    install_name_tool -id "@rpath/libqwen3.dylib" "$LIB"
done

# Generate a dSYM per slice so crashes touching libqwen3.dylib can be
# symbolicated (App Store Connect "Upload Symbols Failed" otherwise).
dsymutil "$MAC_DYLIB" -o "$MAC_DYLIB.dSYM"
dsymutil "$IOS_DYLIB" -o "$IOS_DYLIB.dSYM"
dsymutil "$IOS_SIM_DYLIB" -o "$IOS_SIM_DYLIB.dSYM"

xcodebuild -create-xcframework \
    -library "$MAC_DYLIB" -headers "$BUILD_DIR/include" -debug-symbols "$MAC_DYLIB.dSYM" \
    -library "$IOS_DYLIB" -headers "$BUILD_DIR/include" -debug-symbols "$IOS_DYLIB.dSYM" \
    -library "$IOS_SIM_DYLIB" -headers "$BUILD_DIR/include" -debug-symbols "$IOS_SIM_DYLIB.dSYM" \
    -output "$OUTPUT_XCFRAMEWORK"

echo "Created $OUTPUT_XCFRAMEWORK"
echo "=== Done ==="
