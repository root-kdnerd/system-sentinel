FROM alpine:3.19

RUN apk add --no-cache bash coreutils procps util-linux bc curl jq grep \
    docker-cli openssh-client net-tools iproute2-ss \
    && mkdir -p /app/config /app/snapshots /app/reports /app/logs

WORKDIR /app

COPY system-sentinel.sh /app/
COPY README.md /app/

RUN chmod +x /app/system-sentinel.sh

ENV SENTINEL_BASE_DIR=/app
ENV SENTINEL_LOG_FILE=/app/logs/system-sentinel.log

VOLUME ["/app/config", "/app/snapshots", "/app/reports", "/app/logs", "/var/run/docker.sock"]

ENTRYPOINT ["/app/system-sentinel.sh"]
CMD ["help"]