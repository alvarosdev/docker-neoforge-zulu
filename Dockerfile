# -- Build ---
FROM azul/zulu-openjdk-alpine:21-jre AS build
LABEL maintainer="Sebas Álvaro <https://alvaros.dev>"

ARG NFVERSION=21.1.219

RUN apk add --no-cache curl

WORKDIR /opt/minecraft

COPY ./scripts/get_neoforge.sh .

RUN chmod +x ./get_neoforge.sh && \
    sh ./get_neoforge.sh ${NFVERSION}


RUN echo "eula=true" > eula.txt
RUN java -jar neoforge.jar --installServer && \
    rm neoforge.jar

# --- Runtime ---
FROM azul/zulu-openjdk-alpine:21-jre AS runtime
LABEL maintainer="Sebas Álvaro <https://alvaros.dev>"

WORKDIR /data

# Install su-exec (lightweight gosu alternative for Alpine)
RUN apk add --no-cache su-exec rcon && \
    ln -s /sbin/su-exec /usr/bin/gosu

COPY --from=build /opt/minecraft /opt/minecraft

VOLUME "/data"

EXPOSE 25565/tcp
EXPOSE 25565/udp

# Environment variables with defaults
ENV MEMORYSIZE=5G
ENV JAVAFLAGS="--add-modules=jdk.incubator.vector -Dlog4j2.formatMsgNoLookups=true -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=mcflags.emc.gs"

COPY scripts/entrypoint.sh /opt/minecraft
RUN chmod +x /opt/minecraft/entrypoint.sh

# Healthcheck using rcon (requires RCON enabled in server.properties)
HEALTHCHECK --interval=60s --timeout=10s --start-period=120s --retries=3 \
    CMD rcon --minecraft --host localhost --port 25575 --password minecraft list || exit 1


ENTRYPOINT ["/opt/minecraft/entrypoint.sh"]
