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
FRAMEWORK_NAME="libssl"
FRAMEWORK_STAGE_DIR="./build/framework-staging"
XCFRAMEWORK_COMMAND=()

rm -rf "$FRAMEWORK_STAGE_DIR" || true

plist_platform_for_variant() {
    case "$1" in
        macosx) echo "MacOSX" ;;
        maccatalyst) echo "iPhoneOS" ;;
        iphoneos) echo "iPhoneOS" ;;
        iphonesimulator) echo "iPhoneSimulator" ;;
        appletvos) echo "AppleTVOS" ;;
        appletvsimulator) echo "AppleTVSimulator" ;;
        watchos) echo "WatchOS" ;;
        watchsimulator) echo "WatchSimulator" ;;
        xros) echo "XROS" ;;
        xrsimulator) echo "XRSimulator" ;;
        *)
            echo "[!] Unknown variant: $1" >&2
            exit 1
            ;;
    esac
}

stage_framework() {
    local variant="$1"
    local library_path="$2"
    local header_dir="$3"
    local framework_path="$FRAMEWORK_STAGE_DIR/$variant/$FRAMEWORK_NAME.framework"
    local modules_dir="$framework_path/Modules"
    local headers_dir="$framework_path/Headers"
    local platform

    platform=$(plist_platform_for_variant "$variant")

    rm -rf "$framework_path"
    mkdir -p "$headers_dir" "$modules_dir"
    cp "$library_path" "$framework_path/$FRAMEWORK_NAME"
    cp -R "$header_dir/." "$headers_dir/"
    mv "$headers_dir/module.modulemap" "$modules_dir/module.modulemap"
    sed -i '' "1s/^module $FRAMEWORK_NAME/framework module $FRAMEWORK_NAME/" "$modules_dir/module.modulemap"
    find "$headers_dir/openssl" -type f -name '*.h' -exec \
        perl -0pi -e 's/#include <openssl\/([^>]+)>/#include "$1"/g' {} +

    cat >"$framework_path/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$FRAMEWORK_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.lakr233.openssl-spm.$FRAMEWORK_NAME</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$FRAMEWORK_NAME</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>$platform</string>
    </array>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
EOF

    XCFRAMEWORK_COMMAND+=("-framework" "$framework_path")
}

for TARGET_LIBRARY_PATH in $(find "$ARTIFACTS_DIR" -name "$TARGET_LIBRARY_NAME" | sort); do
    VARIANT=$(basename "$(dirname "$(dirname "$TARGET_LIBRARY_PATH")")")
    TARGET_HEADER_DIR=$(dirname $(dirname "$TARGET_LIBRARY_PATH"))/include
    echo "[*] Target library: $TARGET_LIBRARY_PATH"
    echo "[*] Target headers: $TARGET_HEADER_DIR"
    stage_framework "$VARIANT" "$TARGET_LIBRARY_PATH" "$TARGET_HEADER_DIR"
done

XCFRAMEWORK_PATH="./BinaryTarget/OpenSSL.Package.xcframework"
rm -rf "$XCFRAMEWORK_PATH" || true

echo "[*] Creating xcframework..."
xcodebuild -create-xcframework \
    -output "$XCFRAMEWORK_PATH" \
    "${XCFRAMEWORK_COMMAND[@]}"

echo "[*] Checking symlinks in xcframework..."
find "$XCFRAMEWORK_PATH" -type l

echo "[*] Packing xcframework with ditto (preserve symlinks)..."
pushd ./BinaryTarget >/dev/null
ditto -c -k --sequesterRsrc --keepParent OpenSSL.Package.xcframework OpenSSL.Package.xcframework.zip
popd >/dev/null

echo "[*] Verifying zip contents..."
ditto -x -k ./BinaryTarget/OpenSSL.Package.xcframework.zip /tmp/verify-xcframework
find /tmp/verify-xcframework -type l

rm -rf "$XCFRAMEWORK_PATH"
mv ./BinaryTarget/OpenSSL.Package.xcframework.zip "$OUTPUT_ZIP"

echo "[*] XCFramework created: $OUTPUT_ZIP"
