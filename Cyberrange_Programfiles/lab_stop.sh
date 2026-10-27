#!/usr/bin/env bash
# ==============================================================================
#   CyberRange SOC Lab Stopper — CyberRange 2.0 Edition
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/cyberrange" ]]; then
    exec "$SCRIPT_DIR/cyberrange" stop "$@"
elif command -v cyberrange &>/dev/null; then
    exec cyberrange stop "$@"
fi

# Fallback
docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
pkill -f "python3 -m http.server 9000" 2>/dev/null || true
echo "Lab stopped."