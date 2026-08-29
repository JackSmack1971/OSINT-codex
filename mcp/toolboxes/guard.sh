#!/bin/sh
set -eu

fail() { echo "OSINT execution denied: $*" >&2; exit 64; }

[ "${OSINT_TOOL:-}" = "sherlock" ] || [ "${OSINT_TOOL:-}" = "maigret" ] || [ "${OSINT_TOOL:-}" = "holehe" ] || [ "${OSINT_TOOL:-}" = "theharvester" ] || [ "${OSINT_TOOL:-}" = "spiderfoot" ] || [ "${OSINT_TOOL:-}" = "amass" ] || [ "${OSINT_TOOL:-}" = "subfinder" ] || [ "${OSINT_TOOL:-}" = "httpx" ] || [ "${OSINT_TOOL:-}" = "nuclei" ] || [ "${OSINT_TOOL:-}" = "gitleaks" ] || [ "${OSINT_TOOL:-}" = "trufflehog" ] || fail "unknown utility"
[ -n "${OSINT_CASE_ID:-}" ] || fail "OSINT_CASE_ID is required"
[ -n "${OSINT_TARGET:-}" ] || fail "OSINT_TARGET is required"
[ -n "${OSINT_SCOPE:-}" ] || fail "OSINT_SCOPE is required"
[ -d "/case/${OSINT_CASE_ID}" ] || fail "active case directory is not mounted"
case_json="/case/${OSINT_CASE_ID}/case.json"
[ -f "$case_json" ] || fail "structured case authorization is not mounted"
grep -Fq '"case_id": "'"${OSINT_CASE_ID}"'"' "$case_json" || fail "case_id is not bound to the active case"
grep -Fq '"target": "'"${OSINT_TARGET}"'"' "$case_json" || fail "target is not bound to the active case"
grep -Fq '"scope": "'"${OSINT_SCOPE}"'"' "$case_json" || fail "scope is not bound to the active case"
grep -Fq '"state": "authorized"' "$case_json" || fail "structured authorization is not currently authorized"

case "$OSINT_TOOL" in
  sherlock) command_name=sherlock ;;
  maigret) command_name=maigret ;;
  holehe) command_name=holehe ;;
  theharvester) command_name=theHarvester ;;
  spiderfoot) command_name=sf.py ;;
  amass) command_name=amass ;;
  subfinder) command_name=subfinder ;;
  httpx) command_name=httpx ;;
  nuclei) command_name=nuclei ;;
  gitleaks) command_name=gitleaks ;;
  trufflehog) command_name=trufflehog ;;
esac

if [ "${1:-}" = "$command_name" ]; then shift; fi

case "$OSINT_TOOL" in
  sherlock|maigret|holehe)
    [ "${OSINT_ENABLE_SENSITIVE:-}" = "1" ] || fail "$OSINT_TOOL requires OSINT_ENABLE_SENSITIVE=1 and target-specific authorization" ;;
  httpx)
    [ "${OSINT_ENABLE_LOW_IMPACT_HTTP:-}" = "1" ] || fail "httpx requires explicit low-impact ROE approval" ;;
  nuclei)
    [ "${OSINT_ENABLE_VULN_TEMPLATES:-}" = "1" ] || fail "nuclei is disabled during normal OSINT" ;;
esac

case "$OSINT_TOOL" in
  subfinder) [ "$#" -eq 1 ] && [ "$1" = "$OSINT_TARGET" ] || fail "schema permits only the authorized target" ;;
  amass) [ "$#" -eq 0 ] || fail "schema permits passive enumeration only" ;;
  gitleaks) [ "$#" -ge 3 ] && [ "$1" = "detect" ] && [ "$2" = "--source" ] && [ "$3" = "/case" ] || fail "schema permits only redacted case scanning" ;;
  trufflehog) [ "$#" -eq 2 ] && [ "$1" = "filesystem" ] && [ "$2" = "/case" ] || fail "schema permits only case filesystem scanning" ;;
  *) for argument in "$@"; do case "$argument" in --active|--scan|--brute*|--password*|--token*|--verify|--validate|--login|--reset|--exploit|--update-templates|--redact=false|-active|-brute|-b|-m|--modules) fail "unsafe argument: $argument" ;; esac; done ;;
esac

case "$OSINT_TOOL" in
  amass) set -- enum -passive "$@" ;;
  subfinder) set -- -silent "$@" ;;
  theharvester) set -- -b "bing,brave,duckduckgo,crtsh" "$@" ;;
  spiderfoot) set -- -m "sfp_dnsresolve,sfp_whois,sfp_crt,sfp_sslcert,sfp_dnsraw" "$@" ;;
  gitleaks) set -- "$@" --redact ;;
  trufflehog)
    if "$command_name" "$@" | /opt/osint/redact-output.sh; then exit 0; else exit 1; fi ;;
esac

status=0
"$command_name" "$@" 2>&1 | /opt/osint/redact-output.sh || status=$?
exit "$status"
