#!/bin/bash
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${CYAN}[+] Stopping CyberRange Docker Containers...${NC}"
docker compose down

echo -e "${CYAN}[+] Stopping Info Page HTTP Server...${NC}"
pkill -f "python3 -m http.server 9000" || true

echo -e "${GREEN}âœ… Lab stopped successfully.${NC}"