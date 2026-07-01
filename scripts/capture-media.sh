#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${ROOT}/.media-build"
IMG_DIR="${ZENN_IMAGES_DIR:-/Users/m_m/develop/9999_m2lab/m-zenn-dev/images}"
PORT="${DEMO_PORT:-19080}"
BASE="http://localhost:${PORT}"
SHOW_BASE="http://localhost:8080"
FONT="/System/Library/Fonts/Menlo.ttc"
PYTHON="${ZENN_MEDIA_PYTHON:-python3}"
if ! "$PYTHON" -c "from PIL import Image" 2>/dev/null; then
  VENV="${ROOT}/.media-venv"
  if [[ ! -x "${VENV}/bin/python" ]]; then
    python3 -m venv "$VENV"
    "${VENV}/bin/pip" install -q pillow
  fi
  PYTHON="${VENV}/bin/python"
fi

mkdir -p "$WORK" "$IMG_DIR"

render_png() {
  local outfile="$1"
  local textfile="$2"
  "$PYTHON" "${ROOT}/scripts/render_terminal_png.py" "$textfile" "$outfile"
}

capture_routing() {
  local f="${WORK}/routing.txt"
  {
    echo "\$ curl -s ${SHOW_BASE}/api/a/"
    curl -s "${BASE}/api/a/"
    echo
    echo "\$ curl -s ${SHOW_BASE}/api/b/"
    curl -s "${BASE}/api/b/"
    echo
    echo "\$ curl -s -D - -o /dev/null ${SHOW_BASE}/api/a/ | grep -E 'HTTP|X-Gateway|X-Request'"
    curl -s -D - -o /dev/null "${BASE}/api/a/" | grep -E 'HTTP|X-Gateway|X-Request'
  } > "$f"
  render_png "${IMG_DIR}/nginx-gateway-demo-routing.png" "$f"
}

capture_fallback() {
  local f="${WORK}/fallback.txt"
  docker compose -f "${ROOT}/docker-compose.yml" stop api-a >/dev/null
  sleep 1
  {
    echo "\$ docker compose stop api-a"
    echo "\$ curl -i --max-time 5 ${SHOW_BASE}/api/a/"
    curl -i --max-time 5 "${BASE}/api/a/"
  } > "$f"
  docker compose -f "${ROOT}/docker-compose.yml" start api-a >/dev/null
  sleep 1
  render_png "${IMG_DIR}/nginx-gateway-demo-fallback.png" "$f"
}

capture_rate_limit_gif() {
  local codes=()
  sleep 2
  for _ in $(seq 1 8); do
    codes+=("$(curl -s -o /dev/null -w '%{http_code}' "${BASE}/api/a/")")
  done

  local i
  for i in $(seq 1 8); do
    {
      echo "\$ for i in \$(seq 1 8); do"
      echo "    curl -s -o /dev/null -w \"%{http_code}\\n\" ${SHOW_BASE}/api/a/"
      echo "  done"
      echo
      local j
      for j in $(seq 1 "$i"); do
        echo "req ${j}: ${codes[$((j - 1))]}"
      done
    } > "${WORK}/rate-plain-$(printf '%02d' "$i").txt"
    render_png "${WORK}/rate-$(printf '%02d' "$i").png" "${WORK}/rate-plain-$(printf '%02d' "$i").txt"
  done

  ffmpeg -y -loglevel error \
    -framerate 2 \
    -i "${WORK}/rate-%02d.png" \
    -vf "fps=2,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
    "${IMG_DIR}/nginx-gateway-demo-rate-limit.gif"
}

cd "$ROOT"
docker compose ps --format '{{.Status}}' | grep -q Up || DEMO_PORT="$PORT" docker compose up -d

capture_routing
capture_rate_limit_gif
capture_fallback

echo "created:"
echo "  ${IMG_DIR}/nginx-gateway-demo-routing.png"
echo "  ${IMG_DIR}/nginx-gateway-demo-rate-limit.gif"
echo "  ${IMG_DIR}/nginx-gateway-demo-fallback.png"
