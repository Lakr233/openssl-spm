#!/bin/bash

set -e

cd $(dirname $0)/..

if [ ! -f .root ]; then
    echo "[*] malformated project structure"
    exit 1
fi

XCFRAMEWORK_PATH_ZIP=$1
DOWNLOAD_URL=$2

if [ ! -f "$XCFRAMEWORK_PATH_ZIP" ]; then
    echo "[*] $XCFRAMEWORK_PATH_ZIP not found"
    exit 1
fi

SHA256SUM=$(shasum -a 256 "$XCFRAMEWORK_PATH_ZIP" | awk '{print $1}')

rm -rf Package.swift

PACKAGE_MANIFEST=$(cat Package.swift.template)
PACKAGE_MANIFEST=${PACKAGE_MANIFEST/__DOWNLOAD_URL__/$DOWNLOAD_URL}
PACKAGE_MANIFEST=${PACKAGE_MANIFEST/__CHECKSUM__/$SHA256SUM}

echo "$PACKAGE_MANIFEST" > Package.swift

cat Package.swift

echo "[*] done $(basename $0)"
