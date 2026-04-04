#!/bin/bash

set -e

cd $(dirname $0)/..

if [ ! -f .root ]; then
    echo "[*] malformated project structure"
    exit 1
fi

if [ -z "$1" ]; then
    for i in {1..10}; do
        OPENSSL_TAG=$(curl -s -L -o /dev/null -w "%{url_effective}\n" https://github.com/openssl/openssl/releases/latest | sed 's|.*/tag/\(.*\)|\1|')
        if [ -n "$OPENSSL_TAG" ]; then
            break
        fi
        sleep 10
    done

    if [ -z "$OPENSSL_TAG" ]; then
        echo "[*] failed to get latest openssl tag"
        exit 1
    fi
else
    OPENSSL_TAG=$1
fi
echo "[*] building for openssl tag: $OPENSSL_TAG"

if [ -n "$2" ]; then
    DOWNLOAD_URL=$2
else
    REPO_SLUG=$(git config --get remote.origin.url | sed -E 's#(git@github.com:|https://github.com/)([^/]+/[^/.]+)(\.git)?#\2#')
    if [ -z "$REPO_SLUG" ]; then
        REPO_SLUG="Lakr233/openssl-spm"
    fi
    STORAGE_RELEASE_TAG="storage.${OPENSSL_TAG#openssl-}"
    DOWNLOAD_URL="https://github.com/$REPO_SLUG/releases/download/$STORAGE_RELEASE_TAG/libssl.xcframework.zip"
fi
echo "[*] manifest download url: $DOWNLOAD_URL"

ARTIFACTS_DIR="$(pwd)/build/dest"
XCFRAMEWORK_PATH_ZIP="$(pwd)/build/libssl.xcframework.zip"
rm -rf "$ARTIFACTS_DIR" "$XCFRAMEWORK_PATH_ZIP"
mkdir -p "$ARTIFACTS_DIR"
mkdir -p "$(dirname "$XCFRAMEWORK_PATH_ZIP")"
echo "[*] output: $XCFRAMEWORK_PATH_ZIP"

./Script/build-platform.sh "$OPENSSL_TAG" macos "$ARTIFACTS_DIR"
./Script/build-platform.sh "$OPENSSL_TAG" ios "$ARTIFACTS_DIR"
./Script/build-platform.sh "$OPENSSL_TAG" tvos "$ARTIFACTS_DIR"
./Script/build-platform.sh "$OPENSSL_TAG" watchos "$ARTIFACTS_DIR"
./Script/build-platform.sh "$OPENSSL_TAG" visionos "$ARTIFACTS_DIR"
./Script/merge-xcframework.sh "$ARTIFACTS_DIR" "$XCFRAMEWORK_PATH_ZIP"
./Script/build-manifest.sh "$XCFRAMEWORK_PATH_ZIP" "$DOWNLOAD_URL"

echo "[*] done $(basename $0)"
