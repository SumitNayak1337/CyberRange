#!/usr/bin/env bash
# ==============================================================================
#   CyberRange SOC Lab Reset — CyberRange 2.0 Edition
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/cyberrange" ]]; then
    exec "$SCRIPT_DIR/cyberrange" reset "$@"
elif command -v cyberrange &>/dev/null; then
    exec cyberrange reset "$@"
fi

echo "Warning: Resetting lab."
read -p "Are you sure? (y/N): " confirm
if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    docker compose down -v 2>/dev/null || docker-compose down -v 2>/dev/null || true
    sudo rm -rf /var/log/suricata/* 2>/dev/null || true
    docker system prune -f 2>/dev/null || true
    ./lab-start.sh
fi
