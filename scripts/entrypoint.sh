#!/bin/sh
set -e

# Default Environment Variables
DOCKER_USER='minecraft'
DOCKER_GROUP='minecraft'
MEMORYSIZE=${MEMORYSIZE:-"2G"}
# Aikar's flags optimized for G1GC (Standard high-performance Minecraft flags)
JAVAFLAGS=${JAVAFLAGS:-"--add-modules=jdk.incubator.vector -Dlog4j2.formatMsgNoLookups=true -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1"}

log() {
    echo "[Entrypoint] $1"
}

# --- User/Group Initialization ---
USER_ID=${PUID:-9001}
GROUP_ID=${PGID:-9001}

# 1. Handle Group
if getent group "$GROUP_ID" >/dev/null 2>&1; then
    log "GID $GROUP_ID exists. Reusing..."
    DOCKER_GROUP=$(getent group "$GROUP_ID" | cut -d: -f1)
else
    log "Creating group $DOCKER_GROUP with GID $GROUP_ID"
    addgroup -g "$GROUP_ID" "$DOCKER_GROUP"
fi

# 2. Handle User
if id "$DOCKER_USER" >/dev/null 2>&1; then
    log "User $DOCKER_USER exists. Reusing..."
    EXISTING_UID=$(id -u "$DOCKER_USER")
    if [ "$EXISTING_UID" != "$USER_ID" ]; then
        log "WARNING: User $DOCKER_USER has UID $EXISTING_UID, but requested $USER_ID. Using existing UID."
        USER_ID=$EXISTING_UID
    fi
elif id -u "$USER_ID" >/dev/null 2>&1; then
    log "UID $USER_ID exists. Reusing..."
    DOCKER_USER=$(getent passwd "$USER_ID" | cut -d: -f1)
else
    log "Creating user $DOCKER_USER with UID $USER_ID"
    adduser -u "$USER_ID" -G "$DOCKER_GROUP" -s /bin/sh -D "$DOCKER_USER"
fi

# 3. Permissions
# We skip recursive chown to avoid slow startups.
# The user is responsible for volume permissions, or Docker handles it.
# We ensure the process runs as the requested UID:GID below using gosu.
log "Permissions: Assuming /data is owned by $USER_ID:$GROUP_ID"

# Set HOME to /data to ensure config persistence (.minecraft folder etc)
export HOME=/data

# --- Library Symlinking ---
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

# --- EULA Handling ---
if [ -f "eula.txt" ]; then
    if grep -q "eula=false" "eula.txt"; then
        log "eula.txt found with false. Setting to true..."
        sed -i 's/eula=false/eula=true/g' eula.txt
    fi
else
    log "Generating eula.txt..."
    echo "eula=true" > eula.txt
fi

# --- Find Arguments File ---
# Use 'head -n 1' to avoid multiple results breaking the script
LAUNCH_ARGS=$(find /opt/minecraft/libraries -name "unix_args.txt" | head -n 1)

if [ -z "$LAUNCH_ARGS" ]; then
    log "CRITICAL ERROR: unix_args.txt not found in /opt/minecraft/libraries"
    exit 1
fi

log "Starting NeoForge as $DOCKER_USER($USER_ID):$DOCKER_GROUP($GROUP_ID)"
log "Memory: $MEMORYSIZE"
log "Flags: $JAVAFLAGS"
log "Args File: $LAUNCH_ARGS"

# --- Execute Java ---
# Use numeric IDs for gosu to avoid name resolution caching issues
exec gosu "$USER_ID:$GROUP_ID" java \
    -Xms"$MEMORYSIZE" \
    -Xmx"$MEMORYSIZE" \
    $JAVAFLAGS \
    @"$LAUNCH_ARGS" \
    nogui \
    "$@"