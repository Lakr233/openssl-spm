#!/bin/bash

# Merge built platform artifacts into an xcframework
# Usage: ./merge-xcframework.sh <artifacts_dir> <output_zip>
# Expects artifacts_dir to contain: macosx, maccatalyst, iphoneos, iphonesimulator,
#   appletvos, appletvsimulator, watchos, watchsimulator, xros, xrsimulator

set -e

cd $(dirname $0)/..
if [ ! -f .root ]; then
    echo "[*] malformed project structure"
    exit 1
fi

ARTIFACTS_DIR=$1
OUTPUT_ZIP=$2

if [ -z "$ARTIFACTS_DIR" ] || [ -z "$OUTPUT_ZIP" ]; then
    echo "Usage: $0 <artifacts_dir> <output_zip>"
    exit 1
fi

echo "[*] Merging xcframework from: $ARTIFACTS_DIR"
echo "[*] Output: $OUTPUT_ZIP"

# Verify all required platforms exist
REQUIRED_PLATFORMS="macosx maccatalyst iphoneos iphonesimulator appletvos appletvsimulator watchos watchsimulator xros xrsimulator"
for platform in $REQUIRED_PLATFORMS; do
    if [ ! -d "$ARTIFACTS_DIR/$platform" ]; then
        echo "[!] Missing platform: $platform"
        exit 1
    fi
    echo "[*] Found platform: $platform"
done

TARGET_LIBRARY_NAME="libssl.a"
XCFRAMEWORK_COMMAND=()

for TARGET_LIBRARY_PATH in $(find "$ARTIFACTS_DIR" -name "$TARGET_LIBRARY_NAME" | sort); do
    TARGET_HEADER_DIR=$(dirname $(dirname "$TARGET_LIBRARY_PATH"))/include
    echo "[*] Target library: $TARGET_LIBRARY_PATH"
    echo "[*] Target headers: $TARGET_HEADER_DIR"
    XCFRAMEWORK_COMMAND+=("-library" "$TARGET_LIBRARY_PATH" "-headers" "$TARGET_HEADER_DIR")
done

XCFRAMEWORK_PATH="./BinaryTarget/OpenSSL.Package.xcframework"
rm -rf "$XCFRAMEWORK_PATH" || true

echo "[*] Creating xcframework..."
xcodebuild -create-xcframework \
    -output "$XCFRAMEWORK_PATH" \
    "${XCFRAMEWORK_COMMAND[@]}"

pushd ./BinaryTarget >/dev/null
zip -r9 OpenSSL.Package.xcframework.zip OpenSSL.Package.xcframework
popd >/dev/null

rm -rf "$XCFRAMEWORK_PATH"
mv ./BinaryTarget/OpenSSL.Package.xcframework.zip "$OUTPUT_ZIP"

echo "[*] XCFramework created: $OUTPUT_ZIP"
