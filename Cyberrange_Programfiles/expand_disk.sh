#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}   Ubuntu LVM Disk Expansion Script       ${NC}"
echo -e "${CYAN}==========================================${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (or use sudo).${NC}"
  exit 1
fi

echo -e "${GREEN}[*] Detecting Root Logical Volume...${NC}"
ROOT_LV=$(df / | tail -1 | awk '{print $1}')

if [[ ! "$ROOT_LV" == *"/dev/mapper/"* ]]; then
    echo -e "${RED}[!] Could not detect an LVM partition for root. Your disk might not be using LVM.${NC}"
    echo "Current Root Partition: $ROOT_LV"
    exit 1
fi

echo -e "${GREEN}[*] Expanding Logical Volume to claim 100% of FREE space...${NC}"
lvextend -l +100%FREE "$ROOT_LV" || true

echo -e "${GREEN}[*] Resizing the filesystem...${NC}"
resize2fs "$ROOT_LV" || true

echo -e "${CYAN}==========================================${NC}"
echo -e "${GREEN}[+] SUCCESS: Disk completely expanded!${NC}"
echo -e "${CYAN}==========================================${NC}"
echo -e "New Disk Space Allocation:"
df -h /
