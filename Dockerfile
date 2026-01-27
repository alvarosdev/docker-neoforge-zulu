# -- Build ---
FROM azul/zulu-openjdk-alpine:21-jre AS build
LABEL maintainer="Sebas Álvaro <https://alvaros.dev>"

ARG NFVERSION=21.1.219

RUN apk add --no-cache curl

WORKDIR /opt/minecraft

COPY ./scripts/get_neoforge.sh .

# Install NeoForge and clean up artifacts in the same layer to save space
RUN chmod +x ./get_neoforge.sh && \
    sh ./get_neoforge.sh ${NFVERSION} && \
    java -jar neoforge.jar --installServer && \
    rm neoforge.jar get_neoforge.sh installer.log 2>/dev/null || true

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

# Environment variables
ENV MEMORYSIZE=5G
# JAVAFLAGS defaults are handled in entrypoint.sh to keep Dockerfile clean
ENV JAVAFLAGS=""

COPY scripts/entrypoint.sh /opt/minecraft
RUN chmod +x /opt/minecraft/entrypoint.sh

# Healthcheck using rcon (requires RCON enabled in server.properties)
HEALTHCHECK --interval=60s --timeout=10s --start-period=120s --retries=3 \
    CMD rcon --minecraft --host localhost --port 25575 --password minecraft list || exit 1


ENTRYPOINT ["/opt/minecraft/entrypoint.sh"]
