FROM docker.io/library/alpine:3.22 AS production

# Container build arguments
ARG LOGROTATE_VERSION=latest
ARG CONTAINER_UID=1000
ARG CONTAINER_GID=1000

ENV CONTAINER_UID=${CONTAINER_UID} \
    CONTAINER_GID=${CONTAINER_GID}

# Install logrotate and go-cron - also create logrotate user and group
RUN addgroup -g $CONTAINER_GID logrotate && \
    adduser -u $CONTAINER_UID -G logrotate -h /usr/bin/logrotate.d -s /bin/bash -S logrotate && \
    apk add --update tar gzip wget tzdata && \
    if  [ "${LOGROTATE_VERSION}" = "latest" ]; \
    then apk add logrotate ; \
    else apk add "logrotate=${LOGROTATE_VERSION}"; \
    fi && \
    mkdir -p /usr/bin/logrotate.d && \
    wget --no-check-certificate -O /tmp/go-cron.tar.gz https://github.com/michaloo/go-cron/releases/download/v0.0.2/go-cron.tar.gz && \
    tar xvf /tmp/go-cron.tar.gz -C /usr/bin && \
    apk del wget && \
    rm -rf /var/cache/apk/* && rm -rf /tmp/*

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
