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
        maccatalyst) echo "MacOSX" ;;
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

# The lowest OS the staged library was built for, read from its own load
# commands. Taking it from the binary rather than repeating the numbers in
# build-platform.sh keeps the two from drifting: the toolchain raises the
# floor on its own — arm64e forces iOS 14.0 where the build asks for 11.0.
minimum_os_version_for_library() {
    local library_path="$1"

    # Two spellings appear side by side: the current LC_BUILD_VERSION carries
    # "minos", while slices the toolchain still emits the old way — tvOS here —
    # carry LC_VERSION_MIN_TVOS and "version". Read whichever the object has,
    # and take the lowest across architectures, since that is the floor the
    # framework as a whole supports.
    otool -l "$library_path" 2>/dev/null |
        awk '
            /^ *cmd LC_BUILD_VERSION$/ { want = "minos"; next }
            /^ *cmd LC_VERSION_MIN_/ { want = "version"; next }
            want == "minos" && /^ *minos / { print $2; want = ""; next }
            want == "version" && /^ *version / { print $2; want = ""; next }
        ' |
        sort -uV |
        head -n 1
}

version_framework_for_variant() {
    local variant="$1"
    local framework_path="$2"
    local version_dir="$framework_path/Versions/A"

    case "$variant" in
        macosx | maccatalyst) ;;
        *) return 0 ;;
    esac

    mkdir -p "$version_dir/Resources"
    mv "$framework_path/$FRAMEWORK_NAME" "$version_dir/$FRAMEWORK_NAME"
    mv "$framework_path/Headers" "$version_dir/Headers"
    mv "$framework_path/Modules" "$version_dir/Modules"
    mv "$framework_path/Info.plist" "$version_dir/Resources/Info.plist"

    ln -s A "$framework_path/Versions/Current"
    ln -s Versions/Current/$FRAMEWORK_NAME "$framework_path/$FRAMEWORK_NAME"
    ln -s Versions/Current/Headers "$framework_path/Headers"
    ln -s Versions/Current/Modules "$framework_path/Modules"
    ln -s Versions/Current/Resources "$framework_path/Resources"
}

verify_deep_framework_layout() {
    local xcframework_path="$1"
    local framework_path

    while IFS= read -r -d '' framework_path; do
        if [ ! -L "$framework_path/$FRAMEWORK_NAME" ] ||
            [ ! -L "$framework_path/Headers" ] ||
            [ ! -L "$framework_path/Modules" ] ||
            [ ! -L "$framework_path/Resources" ] ||
            [ ! -L "$framework_path/Versions/Current" ] ||
            [ ! -f "$framework_path/Versions/A/Resources/Info.plist" ]; then
            echo "[!] invalid deep framework layout: $framework_path"
            exit 1
        fi
    done < <(find "$xcframework_path" \( -path "*/macos-*/$FRAMEWORK_NAME.framework" -o -path "*-maccatalyst/$FRAMEWORK_NAME.framework" \) -type d -print0)
}

verify_xcframework_zip() {
    local zip_path="$1"
    local xcframework_name="$2"
    local unpack_dir

    unpack_dir=$(mktemp -d)
    ditto -x -k "$zip_path" "$unpack_dir"
    verify_deep_framework_layout "$unpack_dir/$xcframework_name"
    find "$unpack_dir" -type l
    rm -rf "$unpack_dir"
}

stage_framework() {
    local variant="$1"
    local library_path="$2"
    local header_dir="$3"
    local framework_path="$FRAMEWORK_STAGE_DIR/$variant/$FRAMEWORK_NAME.framework"
    local modules_dir="$framework_path/Modules"
    local headers_dir="$framework_path/Headers"
    local platform
    local minimum_os_version
    local minimum_version_key

    platform=$(plist_platform_for_variant "$variant")
    minimum_os_version=$(minimum_os_version_for_library "$library_path")
    if [ -z "$minimum_os_version" ]; then
        echo "[!] Could not read a minimum OS version from: $library_path" >&2
        exit 1
    fi

    # macOS bundles declare their floor as LSMinimumSystemVersion; every other
    # platform, Mac Catalyst included, uses MinimumOSVersion. An app that ships
    # a framework without it is rejected by App Store validation with
    # ITMS-90360 and ITMS-90530.
    case "$variant" in
        macosx) minimum_version_key="LSMinimumSystemVersion" ;;
        *) minimum_version_key="MinimumOSVersion" ;;
    esac

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
    <string>wiki.qaq.openssl-spm.$FRAMEWORK_NAME</string>
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
    <key>$minimum_version_key</key>
    <string>$minimum_os_version</string>
</dict>
</plist>
EOF

    version_framework_for_variant "$variant" "$framework_path"

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

verify_deep_framework_layout "$XCFRAMEWORK_PATH"

echo "[*] Checking symlinks in xcframework..."
find "$XCFRAMEWORK_PATH" -type l

echo "[*] Packing xcframework with ditto (preserve symlinks)..."
pushd ./BinaryTarget >/dev/null
ditto -c -k --sequesterRsrc --keepParent OpenSSL.Package.xcframework OpenSSL.Package.xcframework.zip
popd >/dev/null

echo "[*] Verifying zip contents..."
verify_xcframework_zip ./BinaryTarget/OpenSSL.Package.xcframework.zip OpenSSL.Package.xcframework

rm -rf "$XCFRAMEWORK_PATH"
mv ./BinaryTarget/OpenSSL.Package.xcframework.zip "$OUTPUT_ZIP"

echo "[*] XCFramework created: $OUTPUT_ZIP"
