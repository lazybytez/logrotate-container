FROM docker.io/library/alpine:3.22 AS production

# Container build arguments
ARG image_version=edge
ARG build_commit_sha=unknown
ARG logrotate_version=latest
ARG container_uid=1000
ARG container_gid=1000

ENV container_uid=${container_uid} \
    container_gid=${container_gid} \
    LOGROTATE_CONTAINER_VERSION=${image_version} \
    LOGROTATE_CONTAINER_BUILD_COMMIT=${build_commit_sha}

# Install logrotate and go-cron - also create logrotate user and group
RUN addgroup -g $container_gid logrotate && \
    adduser -u $container_uid -G logrotate -h /usr/bin/logrotate.d -s /bin/bash -S logrotate && \
    apk add --update bash tar gzip tzdata tini && \
    if  [ "${logrotate_version}" = "latest" ]; \
    then apk add logrotate ; \
    else apk add "logrotate=${logrotate_version}"; \
    fi && \
    mkdir -p /usr/bin/logrotate.d && \
    rm -rf /var/cache/apk/* && rm -rf /tmp/*

# Install ofelia for cronjob scheduling
COPY --from=docker.io/mcuadros/ofelia:0.3 /usr/bin/ofelia /usr/bin/ofelia

# Available environment variables for this container
ENV LOGROTATE_OLDDIR= \
    LOGROTATE_COMPRESSION= \
    LOGROTATE_INTERVAL= \
    LOGROTATE_COPIES= \
    LOGROTATE_SIZE= \
    LOGS_DIRECTORIES= \
    LOG_FILE_ENDINGS= \
    LOGROTATE_LOGFILE= \
    LOGROTATE_CRONSCHEDULE= \
    LOGROTATE_PARAMETERS= \
    LOGROTATE_STATUSFILE= \
    LOG_FILE=

# Copy entrypoint and helper scripts
COPY container-entrypoint.sh /container-entrypoint.sh
COPY logrotate.d/ /usr/bin/logrotate.d/

# Specify default volumes
VOLUME ["/logrotate-status"]

# Configure container labels
## General image informations
LABEL author="Lazy Bytez"
LABEL maintainer="contact@lazybytez.de"

## Open Container annotations
LABEL org.opencontainers.image.title="Logrotate Container"
LABEL org.opencontainers.image.description="Logrotate container image based on blacklabelops/logrotate"
LABEL org.opencontainers.image.vendor="Lazy Bytez"
LABEL org.opencontainers.image.source="https://github.com/lazybytez/logrotate-container"
LABEL org.opencontainers.image.licenses="MIT"

# Set entrypoint and default command
ENTRYPOINT ["/sbin/tini","--","/container-entrypoint.sh"]
CMD ["cron"]
