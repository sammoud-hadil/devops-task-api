#!/usr/bin/env bash
# Smoke test: runs a few HTTP checks against a running container and
# writes a PASSED/FAILED report. Exit code 0 = PASSED, 1 = FAILED.
#
# Usage: scripts/smoke_test.sh <container-name> <report-file>
#
# The checks run *inside* the container with "docker exec", so they work the
# same whether Jenkins runs on the host or inside a Docker container
# (no port mapping or network setup needed).

CONTAINER="$1"
REPORT="${2:-reports/smoke-results.txt}"
mkdir -p "$(dirname "$REPORT")"
: > "$REPORT"
FAILED=0

log() { echo "$1" | tee -a "$REPORT"; }

# Run a Python one-liner inside the container; prints the HTTP status code.
http() {
  docker exec "$CONTAINER" python -c "
import json, sys, urllib.request, urllib.error
method, path, body = sys.argv[1], sys.argv[2], sys.argv[3]
data = body.encode() if body else None
req = urllib.request.Request('http://localhost:5000' + path, data=data, method=method,
                             headers={'Content-Type': 'application/json'})
try:
    print(urllib.request.urlopen(req, timeout=3).status)
except urllib.error.HTTPError as e:
    print(e.code)
except Exception:
    print(0)
" "$1" "$2" "${3:-}" 2>/dev/null || echo 0
}

check() {  # check <name> <expected-code> <method> <path> [json-body]
  local got
  got=$(http "$3" "$4" "${5:-}")
  if [ "$got" = "$2" ]; then
    log "[PASSED] $1 (HTTP $got)"
  else
    log "[FAILED] $1 (expected HTTP $2, got $got)"
    FAILED=1
  fi
}

log "Smoke test on container: $CONTAINER - $(date '+%Y-%m-%d %H:%M:%S')"

# Wait up to 30s for the app to answer.
for i in $(seq 1 30); do
  [ "$(http GET /health)" = "200" ] && break
  sleep 1
done

check "GET /health returns 200"            200 GET  /health
check "GET /api/tasks returns 200"         200 GET  /api/tasks
check "POST /api/tasks creates a task"     201 POST /api/tasks '{"title":"smoke"}'
check "POST /api/tasks without title = 400" 400 POST /api/tasks '{}'

if [ "$FAILED" -eq 0 ]; then
  log "SMOKE RESULT: PASSED"
  exit 0
else
  log "SMOKE RESULT: FAILED"
  docker logs "$CONTAINER" >> "$REPORT" 2>&1 || true
  exit 1
fi
