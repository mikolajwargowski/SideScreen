#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE_DIR="$(cd "$SCRIPT_DIR/../Tools/PenProbe" && pwd)"
PORT="${1:-8765}"

echo "SideScreen Flow Pen Probe: http://127.0.0.1:$PORT"
echo "Press Ctrl+C to stop."
exec python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$PROBE_DIR"
