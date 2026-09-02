# ==============================================================================
# Personal Homepage Runtime Wrapper Image
# ==============================================================================

# renovate: datasource=docker depName=ghcr.io/gethomepage/homepage
ARG HOMEPAGE_VERSION="v2.2.0"

FROM ghcr.io/gethomepage/homepage:${HOMEPAGE_VERSION}

LABEL org.opencontainers.image.title="Personal Homepage"
LABEL org.opencontainers.image.description="Opinionated non-root Homepage image for homelab deployments."
LABEL org.opencontainers.image.source="https://github.com/andygodish/image-homepage"

ENV PUID=10004
ENV PGID=10004
ENV HOMEPAGE_ALLOWED_HOSTS=localhost:3000,127.0.0.1:3000

RUN mkdir -p /app/config/logs && \
    chown -R 10004:10004 /app/config

COPY --chown=10004:10004 version.txt /usr/local/share/version.txt

VOLUME ["/app/config"]

EXPOSE 3000
