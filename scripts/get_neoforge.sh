#!/bin/sh
set -e

NFVERSION=$1

if [ -z "${NFVERSION}" ]; then
    echo "Usage: $0 <minecraft version>"
    exit 1
fi

rm -f neoforge.jar

NEOFORGE_DOWNLOAD_URL=https://maven.neoforged.net/releases/net/neoforged/neoforge/${NFVERSION}/neoforge-${NFVERSION}-installer.jar

echo "------------------------------"
echo "NeoForge Version:                ${NFVERSION}"
echo "Downloading URL:                 ${NEOFORGE_DOWNLOAD_URL}"
echo "------------------------------"

curl -f -s -o neoforge.jar "${NEOFORGE_DOWNLOAD_URL}"
