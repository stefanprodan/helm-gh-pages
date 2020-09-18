FROM stefanprodan/alpine-base:latest

RUN apk --no-cache add git

RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app -h /app app

COPY src/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER app
ENTRYPOINT ["/entrypoint.sh"]
