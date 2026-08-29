ARG PYTHON_IMAGE=python:3.12.11-slim-bookworm
FROM ${PYTHON_IMAGE}

ARG TOOL_REPOSITORY
ARG TOOL_COMMIT

RUN apt-get update \
    && apt-get install --no-install-recommends --yes git ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && git clone --filter=blob:none "${TOOL_REPOSITORY}" /opt/tool \
    && cd /opt/tool \
    && git checkout --detach "${TOOL_COMMIT}" \
    && if [ -f pyproject.toml ] || [ -f setup.py ]; then python -m pip install --no-cache-dir .; elif [ -f requirements.lock ]; then python -m pip install --no-cache-dir --require-hashes -r requirements.lock; elif [ -f requirements.txt ]; then python -m pip install --no-cache-dir -r requirements.txt; else echo "No supported Python install metadata found" >&2; exit 1; fi \
    && useradd --create-home --uid 10001 osint \
    && printf '#!/bin/sh\nexec python /opt/tool/sf.py "$@"\n' > /usr/local/bin/sf.py \
    && chmod 0555 /usr/local/bin/sf.py \
    && chown -R osint:osint /opt/tool

COPY guard.sh /opt/osint/guard.sh
COPY redact-output.sh /opt/osint/redact-output.sh
RUN chmod 0555 /opt/osint/*.sh

USER 10001:10001
WORKDIR /workspace
ENTRYPOINT ["/opt/osint/guard.sh"]
