#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}âš ï¸ WARNING: This will destroy all containers and wipe all local logs/data.${NC}"
read -p "Are you sure? (y/N): " confirm
if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    echo -e "${YELLOW}[+] Tearing down lab and volumes...${NC}"
    docker compose down -v
    
    echo -e "${YELLOW}[+] Wiping Suricata logs...${NC}"
    sudo rm -rf /var/log/suricata/*

    echo -e "${YELLOW}[+] Truncating runaway Docker container logs...${NC}"
    # Empty all docker json logs to instantly reclaim space from restart loops
    sudo sh -c 'truncate -s 0 /var/lib/docker/containers/*/*-json.log 2>/dev/null' || true

    echo -e "${YELLOW}[+] Deep cleaning Docker (pruning unused images, networks, and volumes)...${NC}"
    # Prune stopped containers, dangling images, unused networks
    docker system prune -f
    # Force prune all unused volumes to kill hidden data
    docker volume prune -a -f

    echo -e "${YELLOW}[+] Restarting fresh...${NC}"
    ./lab-start.sh
else
    echo "Aborted."
fi
