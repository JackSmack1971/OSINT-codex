#!/bin/sh
set -eu

sed -E \
  -e 's/("?(Secret|Raw|RawV2|Value|Token|Password|API key)"?[[:space:]]*:[[:space:]]*")[^"]+("?)/\1[REDACTED]\3/Ig' \
  -e 's/(https?:\/\/[^[:space:]]*([?&](key|token|secret|password|sig|signature)=))[^&[:space:]]+/\1[REDACTED]/Ig'
