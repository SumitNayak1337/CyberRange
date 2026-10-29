#!/usr/bin/env bash
# ==============================================================================
#   CyberRange SOC Lab Launcher — CyberRange 2.0 Edition
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Delegate to unified CLI if present
if [[ -f "$SCRIPT_DIR/cyberrange" ]]; then
    exec "$SCRIPT_DIR/cyberrange" start "$@"
elif command -v cyberrange &>/dev/null; then
    exec cyberrange start "$@"
fi

# Fallback standalone execution
GRN='\033[0;32m'
CYN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GRN}[*] SOC Lab initialization sequence started...${NC}"

if docker compose version &>/dev/null; then
    DOCKER_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
    DOCKER_CMD="docker-compose"
else
    echo -e "${RED}[!] Error: docker compose is not installed.${NC}"
    exit 1
fi

# IP Detection
LAN_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || true)
if [[ -z "$LAN_IP" ]]; then
    LAN_IP=$(ip -4 addr show ens33 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1 || true)
fi
if [[ -z "$LAN_IP" ]]; then
    LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
fi
[[ -z "$LAN_IP" ]] && LAN_IP="127.0.0.1"

echo -e "${GRN}[✓] Detected Host IP: $LAN_IP${NC}"

# Kill any existing server on port 9000
pkill -f "python3 -m http.server 9000" 2>/dev/null || true

# Start containers
$DOCKER_CMD up -d

# Start dashboard server
mkdir -p "$SCRIPT_DIR/dashboard"
nohup python3 -m http.server 9000 --directory "$SCRIPT_DIR/dashboard" >/dev/null 2>&1 &

echo -e "${CYN}[+] SUCCESS: CyberRange 2.0 SOC Lab is LIVE!${NC}"
echo -e "  Main Dashboard  → http://${LAN_IP}:9000"
echo -e "  DVWA            → http://${LAN_IP}:8081"
echo -e "  Splunk SIEM     → http://${LAN_IP}:8000"
echo -e "  Shuffle SOAR    → http://${LAN_IP}:3443  [admin / CyberRange@123]"