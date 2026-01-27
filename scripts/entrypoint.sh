#!/bin/sh
set -e

# Default Environment Variables
DOCKER_USER='minecraft'
DOCKER_GROUP='minecraft'
MEMORYSIZE=${MEMORYSIZE:-"2G"}
# Aikar's flags optimized for G1GC (Standard high-performance Minecraft flags)
JAVAFLAGS=${JAVAFLAGS:-"-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1"}

log() {
    echo "[Entrypoint] $1"
}

# User Initialization Logic
if ! id "$DOCKER_USER" >/dev/null 2>&1; then
    log "First start or missing user detected. Initializing..."

    USER_ID=${PUID:-9001}
    GROUP_ID=${PGID:-9001}
    
    log "Setting up user with UID:$USER_ID / GID:$GROUP_ID"

    # Handle Group
    if getent group "$GROUP_ID" >/dev/null 2>&1; then
        log "Group ID $GROUP_ID exists. Reusing..."
        DOCKER_GROUP=$(getent group "$GROUP_ID" | cut -d: -f1)
    else
        addgroup -g "$GROUP_ID" "$DOCKER_GROUP"
    fi

    # Handle User
    if ! id -u "$USER_ID" >/dev/null 2>&1; then
        adduser -u "$USER_ID" -G "$DOCKER_GROUP" -s /bin/sh -D "$DOCKER_USER"
    fi

    log "Applying permissions..."
    chown -R "$USER_ID:$GROUP_ID" /opt/minecraft
    chown -R "$USER_ID:$GROUP_ID" /data
    chmod -R ug+rwx /opt/minecraft
fi

export HOME=/home/$DOCKER_USER

# Library Symlinking
# Ensure /data/libraries points to the container's internal libraries to support updates
if [ -d "/data/libraries" ] && [ ! -L "/data/libraries" ]; then
    log "Found physical directory at /data/libraries. Moving to .bak..."
    rm -rf /data/libraries.bak
    mv /data/libraries /data/libraries.bak
fi

if [ ! -L "/data/libraries" ]; then
    log "Linking /opt/minecraft/libraries -> /data/libraries"
    ln -s /opt/minecraft/libraries /data/libraries
fi

# Find Arguments File
# Use 'head -n 1' to avoid multiple results breaking the script
LAUNCH_ARGS=$(find /opt/minecraft/libraries -name "unix_args.txt" | head -n 1)

if [ -z "$LAUNCH_ARGS" ]; then
    log "CRITICAL ERROR: unix_args.txt not found in /opt/minecraft/libraries"
    exit 1
fi

log "Starting NeoForge..."
log "Memory: $MEMORYSIZE"
log "Flags: $JAVAFLAGS"
log "Args File: $LAUNCH_ARGS"

# Execute Java
exec gosu "$DOCKER_USER:$DOCKER_GROUP" java \
    -Xms"$MEMORYSIZE" \
    -Xmx"$MEMORYSIZE" \
    $JAVAFLAGS \
    @"$LAUNCH_ARGS" \
    nogui \
    "$@"