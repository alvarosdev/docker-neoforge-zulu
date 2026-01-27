#!/bin/sh
set -e

MINECRAFT_VERSION=$1

if [ -z "${MINECRAFT_VERSION}" ]; then
    echo "Usage: $0 <minecraft version>"
    exit 1
fi

rm -f neoforge.jar

if [ -f /neoforge_version.txt ]; then
    . /neoforge_version.txt
    
    LATEST_NEOFORGE_VERSION=$NEOFORGE_VERSION
    LATEST_INSTALLER=$INSTALLER
else
    echo "Error: /neoforge_version.txt not found!"
    exit 1
fi

if [ -z "${LATEST_NEOFORGE_VERSION}" ] || [ -z "${LATEST_INSTALLER}" ]; then
    echo "Error: failed to retrieve versions from neoforge_version.txt"
    exit 1
fi

NEOFORGE_DOWNLOAD_URL=https://maven.neoforged.net/releases/net/neoforged/neoforge/${LATEST_NEOFORGE_VERSION}/neoforge-${LATEST_NEOFORGE_VERSION}-installer.jar

echo "------------------------------"
echo "Minecraft Version:               ${MINECRAFT_VERSION}"
echo "Latest NeoForge Version:         ${LATEST_NEOFORGE_VERSION}"
echo "Latest NeoForge Installer Version: ${LATEST_INSTALLER}"
echo "Downloading URL:                 ${NEOFORGE_DOWNLOAD_URL}"
echo "------------------------------"

curl -f -s -o neoforge.jar "${NEOFORGE_DOWNLOAD_URL}"
