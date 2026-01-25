#!/bin/bash

# Build OpenSSL for specific platforms
# Usage: ./build-platform.sh <openssl_tag> <platform_group> <output_dir>
# Platform groups: macos, ios, tvos, watchos, visionos

set -e

cd $(dirname $0)/..
if [ ! -f .root ]; then
    echo "[*] malformed project structure"
    exit 1
fi

OPENSSL_TAG=$1
PLATFORM_GROUP=$2
OUTPUT_DIR=$3

if [ -z "$OPENSSL_TAG" ] || [ -z "$PLATFORM_GROUP" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Usage: $0 <openssl_tag> <platform_group> <output_dir>"
    echo "Platform groups: macos, ios, tvos, watchos, visionos"
    exit 1
fi

echo "[*] Building OpenSSL $OPENSSL_TAG for $PLATFORM_GROUP"
echo "[*] Output directory: $OUTPUT_DIR"

mkdir -p "build"
pushd "build" >/dev/null
echo "[*] Preparing source code..."
git clone https://github.com/openssl/openssl openssl 2>/dev/null || true
pushd openssl >/dev/null
echo "[*] Cleaning..."
git clean -fdx >/dev/null
git reset --hard >/dev/null
git fetch --tags >/dev/null
git checkout "$OPENSSL_TAG"

SOURCE_DIR=$(pwd)
echo "[*] Source dir: $SOURCE_DIR"
popd >/dev/null
popd >/dev/null

mkdir -p "$OUTPUT_DIR"

# SOURCE_DIR=$1 SDK_PLATFORM=$2 PLATFORM=$3 EFFECTIVE_PLATFORM_NAME=$4 ARCHS=$5 MIN_VERSION=$6 INSTALL_PREFIX=$7

case "$PLATFORM_GROUP" in
macos)
    ./Script/build-openssl.sh "$SOURCE_DIR" "macosx" "MacOSX" "" "x86_64 arm64" "10.15" "$OUTPUT_DIR/macosx"
    ./Script/build-openssl.sh "$SOURCE_DIR" "macosx" "MacOSX" "MAC_CATALYST_13_1" "x86_64 arm64" "10.15" "$OUTPUT_DIR/maccatalyst"
    ;;
ios)
    ./Script/build-openssl.sh "$SOURCE_DIR" "iphoneos" "iPhoneOS" "" "arm64 arm64e" "11.0" "$OUTPUT_DIR/iphoneos"
    ./Script/build-openssl.sh "$SOURCE_DIR" "iphonesimulator" "iPhoneSimulator" "" "x86_64 arm64" "11.0" "$OUTPUT_DIR/iphonesimulator"
    ;;
tvos)
    ./Script/build-openssl.sh "$SOURCE_DIR" "appletvos" "AppleTVOS" "" "arm64" "11.0" "$OUTPUT_DIR/appletvos"
    ./Script/build-openssl.sh "$SOURCE_DIR" "appletvsimulator" "AppleTVSimulator" "" "x86_64 arm64" "11.0" "$OUTPUT_DIR/appletvsimulator"
    ;;
watchos)
    ./Script/build-openssl.sh "$SOURCE_DIR" "watchos" "WatchOS" "" "armv7k arm64_32 arm64" "5.0" "$OUTPUT_DIR/watchos"
    ./Script/build-openssl.sh "$SOURCE_DIR" "watchsimulator" "WatchSimulator" "" "x86_64 arm64" "5.0" "$OUTPUT_DIR/watchsimulator"
    ;;
visionos)
    ./Script/build-openssl.sh "$SOURCE_DIR" "xros" "XROS" "VISION_NOT_PRO" "arm64" "1.0" "$OUTPUT_DIR/xros"
    ./Script/build-openssl.sh "$SOURCE_DIR" "xrsimulator" "XRSimulator" "VISION_NOT_PRO_SIMULATOR" "arm64" "1.0" "$OUTPUT_DIR/xrsimulator"
    ;;
*)
    echo "[!] Unknown platform group: $PLATFORM_GROUP"
    echo "Valid groups: macos, ios, tvos, watchos, visionos"
    exit 1
    ;;
esac

echo "[*] Build complete for $PLATFORM_GROUP"
echo "[*] Output: $OUTPUT_DIR"
