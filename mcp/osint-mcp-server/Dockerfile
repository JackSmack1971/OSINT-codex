FROM node:22-alpine@sha256:76789712cd1ae89a1225eac9077010d68987a423588042dac30446f502f1858c

ARG UPSTREAM_REPOSITORY=https://github.com/badchars/osint-mcp-server.git
ARG UPSTREAM_COMMIT=7611f70e6a82425f1aa1e40d964057ed5f0dcb60

RUN apk add --no-cache ca-certificates git \
    && git clone --filter=blob:none "${UPSTREAM_REPOSITORY}" /opt/osint-mcp-server \
    && cd /opt/osint-mcp-server \
    && git checkout --detach "${UPSTREAM_COMMIT}" \
    && if [ -f package-lock.json ]; then npm ci --ignore-scripts --no-audit --no-fund; else npm install --ignore-scripts --no-audit --no-fund; fi \
    && npm run build \
    && npm prune --omit=dev \
    && apk del git \
    && addgroup -S osint \
    && adduser -S -G osint osint \
    && chown -R osint:osint /opt/osint-mcp-server

USER osint:osint
WORKDIR /opt/osint-mcp-server
ENTRYPOINT ["node", "dist/index.js"]
