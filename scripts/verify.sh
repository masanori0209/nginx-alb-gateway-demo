#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PORT="${DEMO_PORT:-8080}"
BASE="http://localhost:${PORT}"
REPORT="${ROOT}/reports/verify-$(date +%Y%m%d-%H%M%S).log"
mkdir -p reports

{
  echo "# verify nginx-alb-gateway-demo"
  echo "# date: $(date -Iseconds)"
  echo "# base: ${BASE}"
  echo

  echo "## health"
  curl -s -i "${BASE}/health"
  echo

  echo "## route /api/a"
  curl -s -i "${BASE}/api/a/"
  echo

  echo "## route /api/b"
  curl -s -i "${BASE}/api/b/"
  echo

  echo "## rate limit burst"
  for i in $(seq 1 8); do
    code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/api/a/")
    echo "req ${i}: ${code}"
  done
  echo

  echo "## fallback (stop api-a)"
  docker compose stop api-a >/dev/null
  sleep 1
  curl -s -i --max-time 5 "${BASE}/api/a/" || echo "curl failed"
  docker compose start api-a >/dev/null
  sleep 1
  echo

  echo "## recovery"
  curl -s "${BASE}/api/a/"
  echo
} | tee "$REPORT"

echo "saved: $REPORT"
