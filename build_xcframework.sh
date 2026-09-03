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
            -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
            "${COMMON_FLAGS[@]}"
cmake --build . --config Release --target qwen3

# 2. iOS (arm64)
echo "--- Building iOS ---"
mkdir -p "$BUILD_DIR/ios"
cd "$BUILD_DIR/ios"
cmake "$SOURCE_DIR" -DCMAKE_SYSTEM_NAME=iOS \
            -DCMAKE_OSX_SYSROOT=iphoneos \
            -DCMAKE_OSX_ARCHITECTURES=arm64 \
            -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
            "${COMMON_FLAGS[@]}"
cmake --build . --config Release --target qwen3

# 3. iOS Simulator (Universal: arm64 and x86_64)
echo "--- Building iOS Simulator Universal ---"
mkdir -p "$BUILD_DIR/ios_sim"
cd "$BUILD_DIR/ios_sim"
cmake "$SOURCE_DIR" -DCMAKE_SYSTEM_NAME=iOS \
            -DCMAKE_OSX_SYSROOT=iphonesimulator \
            -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
            -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
            "${COMMON_FLAGS[@]}"
cmake --build . --config Release --target qwen3

# --- Create XCFramework ---
echo "--- Creating XCFramework ---"
cd "$PROJECT_DIR"
rm -rf "$OUTPUT_XCFRAMEWORK"

mkdir -p "$BUILD_DIR/include"
cp "$QWEN_HEADER" "$BUILD_DIR/include/"

create_qwen_framework() {
    local PLATFORM_DIR="$1"
    local FW_NAME="Qwen3TTSLib"
    local FW_DIR="$PLATFORM_DIR/$FW_NAME.framework"
    local DYLIB="$PLATFORM_DIR/bin/libqwen3.dylib"
    local MIN_OS="17.0"
    if [[ "$PLATFORM_DIR" == *"mac"* ]]; then
        MIN_OS="14.0"
    fi

    rm -rf "$FW_DIR"
    mkdir -p "$FW_DIR/Headers"
    cp "$DYLIB" "$FW_DIR/$FW_NAME"
    cp "$BUILD_DIR/include/qwen.h" "$FW_DIR/Headers/"
    chmod +w "$FW_DIR/$FW_NAME"
    install_name_tool -id "@rpath/$FW_NAME.framework/$FW_NAME" "$FW_DIR/$FW_NAME"
    codesign --remove-signature "$FW_DIR/$FW_NAME" || true

    cat > "$FW_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>$FW_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>ai.lookbe.$FW_NAME</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$FW_NAME</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>0.0.1</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>MinimumOSVersion</key>
	<string>$MIN_OS</string>
</dict>
</plist>
EOF
}

dsymutil "$BUILD_DIR/mac/bin/libqwen3.dylib" -o "$BUILD_DIR/mac/Qwen3TTSLib.framework.dSYM"
dsymutil "$BUILD_DIR/ios/bin/libqwen3.dylib" -o "$BUILD_DIR/ios/Qwen3TTSLib.framework.dSYM"
dsymutil "$BUILD_DIR/ios_sim/bin/libqwen3.dylib" -o "$BUILD_DIR/ios_sim/Qwen3TTSLib.framework.dSYM"

create_qwen_framework "$BUILD_DIR/mac"
create_qwen_framework "$BUILD_DIR/ios"
create_qwen_framework "$BUILD_DIR/ios_sim"

xcodebuild -create-xcframework \
    -framework "$BUILD_DIR/mac/Qwen3TTSLib.framework" -debug-symbols "$BUILD_DIR/mac/Qwen3TTSLib.framework.dSYM" \
    -framework "$BUILD_DIR/ios/Qwen3TTSLib.framework" -debug-symbols "$BUILD_DIR/ios/Qwen3TTSLib.framework.dSYM" \
    -framework "$BUILD_DIR/ios_sim/Qwen3TTSLib.framework" -debug-symbols "$BUILD_DIR/ios_sim/Qwen3TTSLib.framework.dSYM" \
    -output "$OUTPUT_XCFRAMEWORK"

echo "Created $OUTPUT_XCFRAMEWORK"
echo "=== Done ==="
