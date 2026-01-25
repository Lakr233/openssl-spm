#!/bin/zsh

LIBSSL_TAG=$1
XCFRAMEWORK_PATH_ZIP=$2

set -e

cd $(dirname $0)/..
if [ ! -f .root ]; then
    echo "[*] malformated project structure"
    exit 1
fi

mkdir -p "build"
pushd "build" > /dev/null
echo "[*] prepare source code..."
git clone https://github.com/openssl/openssl openssl || true
pushd openssl > /dev/null
echo "[*] cleaning..."
git clean -fdx > /dev/null
git reset --hard > /dev/null
git checkout "$LIBSSL_TAG"

SOURCE_DIR=$(pwd)
echo "[*] source dir: $SOURCE_DIR"
popd > /dev/null
popd > /dev/null

DEST_PREFIX=$(pwd)/build/dest

# SOURCE_DIR=$1 SDK_PLATFORM=$2 PLATFORM=$3 EFFECTIVE_PLATFORM_NAME=$4 ARCHS=$5 MIN_VERSION=$6

# EFFECTIVE_PLATFORM_NAME Note:
#   this parameter is not used as a compiler flag
#   but for our script to distinguish between different platforms
#   where we may add CFLAG as Xcode does

./Script/build-openssl.sh $SOURCE_DIR "macosx" "MacOSX" "" "x86_64 arm64" "10.15" "$DEST_PREFIX/macosx"
./Script/build-openssl.sh $SOURCE_DIR "macosx" "MacOSX" "MAC_CATALYST_13_1" "x86_64 arm64" "10.15" "$DEST_PREFIX/maccatalyst"

./Script/build-openssl.sh $SOURCE_DIR "iphoneos" "iPhoneOS" "" "arm64 arm64e" "11.0" "$DEST_PREFIX/iphoneos"
./Script/build-openssl.sh $SOURCE_DIR "iphonesimulator" "iPhoneSimulator" "" "x86_64 arm64" "11.0" "$DEST_PREFIX/iphonesimulator"

./Script/build-openssl.sh $SOURCE_DIR "appletvos" "AppleTVOS" "" "arm64" "11.0" "$DEST_PREFIX/appletvos"
./Script/build-openssl.sh $SOURCE_DIR "appletvsimulator" "AppleTVSimulator" "" "x86_64 arm64" "11.0" "$DEST_PREFIX/appletvsimulator"

./Script/build-openssl.sh $SOURCE_DIR "watchos" "WatchOS" "" "armv7k arm64_32 arm64" "5.0" "$DEST_PREFIX/watchos"
./Script/build-openssl.sh $SOURCE_DIR "watchsimulator" "WatchSimulator" "" "x86_64 arm64" "5.0" "$DEST_PREFIX/watchsimulator"

./Script/build-openssl.sh $SOURCE_DIR "xros" "XROS" "VISION_NOT_PRO" "arm64" "1.0" "$DEST_PREFIX/xros"
./Script/build-openssl.sh $SOURCE_DIR "xrsimulator" "XRSimulator" "VISION_NOT_PRO_SIMULATOR" "arm64" "1.0" "$DEST_PREFIX/xrsimulator"

TARGET_LIBRARY_NAME="libssl.a"
XCFRAMEWORK_COMMAND=()
for TARGET_LIBRARY_PATH in $(find $DEST_PREFIX -name "$TARGET_LIBRARY_NAME")
do
  TARGET_HEADER_DIR=$(dirname $(dirname $TARGET_LIBRARY_PATH))/include
  echo "[*] target library: $TARGET_LIBRARY_PATH"
  echo "[*] target headers: $TARGET_HEADER_DIR"
  XCFRAMEWORK_COMMAND+=("-library" "$TARGET_LIBRARY_PATH" "-headers" "$TARGET_HEADER_DIR")
done

rm -rf ./BinaryTarget/OpenSSL.Package.xcframework || true
xcodebuild -create-xcframework \
  -output ./BinaryTarget/OpenSSL.Package.xcframework \
  "${XCFRAMEWORK_COMMAND[@]}"
  ;

zip -r9 ./BinaryTarget/OpenSSL.Package.xcframework.zip ./BinaryTarget/OpenSSL.Package.xcframework
rm -rf ./BinaryTarget/OpenSSL.Package.xcframework

mv ./BinaryTarget/OpenSSL.Package.xcframework.zip "$XCFRAMEWORK_PATH_ZIP"

