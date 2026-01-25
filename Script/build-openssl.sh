#!/bin/bash

set -e

cd $(dirname $0)/..
if [ ! -f .root ]; then
    echo "[*] malformated project structure"
    exit 1
fi
ROOT_DIR=$(pwd)

BEGIN_TIME=$(date +%s)
echo "========================================"
echo "[*] starting build $BEGIN_TIME"
echo "========================================"

SOURCE_DIR=$1
SDK_PLATFORM=$2
PLATFORM=$3
EFFECTIVE_PLATFORM_NAME=$4
ARCHS=$5
MIN_VERSION=$6
INSTALL_PREFIX=$7

rm -rf "$INSTALL_PREFIX" || true
mkdir -p "$INSTALL_PREFIX" || true

echo "[*] source dir: $SOURCE_DIR"
echo "[*] sdk platform: $SDK_PLATFORM"
echo "[*] platform: $PLATFORM"
echo "[*] effective platform name: $EFFECTIVE_PLATFORM_NAME"
echo "[*] archs: $ARCHS"
echo "[*] min version: $MIN_VERSION"
echo "[*] install prefix: $INSTALL_PREFIX"

TEMP_SRC_DIR="$ROOT_DIR/build/temp_src/$(uuidgen)"
echo "[*] duplicated source code to temp dir: $TEMP_SRC_DIR"
mkdir -p "$TEMP_SRC_DIR" || true
cp -r "$SOURCE_DIR" "$TEMP_SRC_DIR/src"
SOURCE_DIR="$TEMP_SRC_DIR/src"
DELIVERED_PREFIXS=()

function cleanup {
  echo "[*] removing temp dir: $TEMP_SRC_DIR"
  rm -rf "$TEMP_SRC_DIR" || true
}

function cleanup_arch_dirs {
  for PREFIX in "${DELIVERED_PREFIXS[@]}"
  do
    echo "[*] removing temp dir: $PREFIX"
    rm -rf "$PREFIX" || true
  done
}
trap cleanup EXIT

for ARCH in $ARCHS
do
  pushd $SOURCE_DIR > /dev/null
  git clean -fdx -f > /dev/null
  git reset --hard > /dev/null
  popd > /dev/null

  echo "========================================"
  echo "==> $SDK_PLATFORM $ARCH $EFFECTIVE_PLATFORM_NAME"
  echo "========================================"

  PREFIX_DIR="$INSTALL_PREFIX.$ARCH"
  rm -rf "$PREFIX_DIR" || true
  mkdir -p "$PREFIX_DIR" || true

  USE_MIN_VERSION=true
  if [[ "$EFFECTIVE_PLATFORM_NAME" == "MAC_CATALYST_13_1" ]]; then
    export CFLAGS="-target $ARCH-apple-ios13.1-macabi -Wno-overriding-option"
  fi
  if [[ "$EFFECTIVE_PLATFORM_NAME" == "VISION_NOT_PRO" ]]; then
    export CFLAGS="-target $ARCH-apple-xros$MIN_VERSION"
    USE_MIN_VERSION=false
  fi
  if [[ "$EFFECTIVE_PLATFORM_NAME" == "VISION_NOT_PRO_SIMULATOR" ]]; then
    export CFLAGS="-target $ARCH-apple-xros$MIN_VERSION-simulator"
    USE_MIN_VERSION=false
  fi

  CONF="no-asm no-shared no-async no-apps no-tests"
  if [[ "$MIN_VERSION" != "" && "$USE_MIN_VERSION" == "true" ]]; then
    CONF="$CONF -m$SDK_PLATFORM-version-min=$MIN_VERSION"
  fi

  HOST="iphoneos-cross"
  if [[ "$SDK_PLATFORM" == "macosx" ]]; then
      HOST="darwin64-$ARCH-cc"
  fi

  export CROSS_TOP="$(xcode-select --print-path)/Platforms/$PLATFORM.platform/Developer"
  export CROSS_SDK="$PLATFORM.sdk"
  export SDKROOT="$CROSS_TOP/SDKs/$CROSS_SDK"
  export CC="$(xcrun --find clang) -arch $ARCH"

  if [[ ! -z "${HOST}" ]]; then 
      echo "    HOST: $HOST"
  fi
  if [[ ! -z "${CONF}" ]]; then
      echo "    CONF: $CONF"
  fi
  if [[ ! -z "${CFLAGS}" ]]; then 
      echo "    CFLAGS: $CFLAGS"
  fi
  if [[ ! -z "${PREFIX_DIR}" ]]; then
      echo "    PREFIX_DIR: $PREFIX_DIR"
  fi

  CONF="$CONF --prefix=$PREFIX_DIR"

  pushd $SOURCE_DIR > /dev/null
  ./config $HOST $CONF > /dev/null

  sed -ie "s!^CFLAG=!CFLAG=-isysroot $SDKROOT !" "Makefile" || true

  echo "[*] building..."
  make -j$(nproc) > /dev/null

  echo "[*] installing to $PREFIX_DIR..."
  make install_sw > /dev/null
  popd > /dev/null

  DELIVERED_PREFIXS+=("$INSTALL_PREFIX.$ARCH")
done

rm -rf "$INSTALL_PREFIX" || true
mkdir -p "$INSTALL_PREFIX" || true

echo "========================================"
echo "[*] creating fat binaries..."
echo "[*] install prefix: $INSTALL_PREFIX"

echo "[*] copying header from: ${ARCHS%% *}"
cp -r "${DELIVERED_PREFIXS[0]}/include" "$INSTALL_PREFIX/include"

echo "[*] searching for static libs..."
STATIC_LIBS=()
pushd ${DELIVERED_PREFIXS[0]}/lib > /dev/null
for file in $(find . -type f -name "*.a")
do
  if [[ "$file" == ./* ]]; then
    file=${file:2}
  fi
  STATIC_LIBS+=("$file")
  echo "[*] found static lib: $file"
done
popd > /dev/null

echo "[*] creating fat static libs..."
pushd "$INSTALL_PREFIX" > /dev/null
mkdir -p "lib" || true
pushd "lib" > /dev/null
USED_LIBS=()
for file in "${STATIC_LIBS[@]}"
do
  echo "[*] creating fat static lib: $file"
  lipo -create $(for PREFIX in "${DELIVERED_PREFIXS[@]}"; do echo "$PREFIX/lib/$file"; done) -output "$file"
  USED_LIBS+=("$file")
done
echo "[*] merging static libs..."
libtool -static -o "libssl_merged.a" "${USED_LIBS[@]}"
rm -rf "${USED_LIBS[@]}" || true
mv "libssl_merged.a" "libssl.a"
file libssl.a
popd > /dev/null
popd > /dev/null

# generate module map located at $BUILT_PRODUCTS_DIR/include/openssl/module.modulemap
pushd "$INSTALL_PREFIX/include/openssl" > /dev/null
echo "[*] generating module map..."
HEADER_FILE_LIST=();
for file in $(find . -type f);
do
  if grep -q "This file is obsolete; please update your software." "$file"; then
    rm "$file"
    continue
  fi
  if [[ "$file" == ./* ]]; then
    file=${file:2};
  fi;
  HEADER_FILE_LIST+=("$file");
done
IFS=$'\n' HEADER_FILE_LIST=($(sort <<<"${HEADER_FILE_LIST[*]}"))

echo "module ssl {" >> module.modulemap
for file in "${HEADER_FILE_LIST[@]}"
do
  echo "    header \"$file\"" >> module.modulemap
done
echo "    export *" >> module.modulemap
echo "}" >> module.modulemap
find . -type d -empty -delete
popd > /dev/null

cleanup_arch_dirs

ELAPSED_TIME=$(expr $(date +%s) - $BEGIN_TIME)
echo "========================================"
echo "[*] finished build in $ELAPSED_TIME sec"
echo "========================================"

echo "[*] done $(basename $0)"
