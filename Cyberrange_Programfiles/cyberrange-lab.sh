#!/usr/bin/env bash
# ==============================================================================
#   CYBERRANGE 2.0 // LAB MANAGER — Add / Remove / List Labs
#   Usage: cyberrange-lab add <lab-name>
#          cyberrange-lab remove <lab-name>
#          cyberrange-lab list
# ==============================================================================

set -eo pipefail

NC='\033[0m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NEON_GREEN='\033[38;5;48m'
NEON_CYAN='\033[38;5;51m'
BOLD='\033[1m'
MUTED='\033[38;5;244m'

# Resolve lab directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/docker-compose.yml" ]]; then
    LAB_DIR="$SCRIPT_DIR"
elif [[ -f "/etc/cyberrange/lab_path" ]]; then
    LAB_DIR="$(cat /etc/cyberrange/lab_path)"
else
    LAB_DIR="/home/cyberrange/CyberRange/Cyberrange_Programfiles"
fi

COMPOSE_FILE="$LAB_DIR/docker-compose.yml"
CUSTOM_DIR="$LAB_DIR/custom-labs"

# ──────────────────────────────────────────────────────────────────
#  AVAILABLE LABS CATALOG (name → docker image, port, description)
# ──────────────────────────────────────────────────────────────────
declare -A LAB_IMAGE LAB_PORT LAB_DESC LAB_MEM

# Red Team Labs
LAB_IMAGE[juice-shop]="bkimminich/juice-shop"
LAB_PORT[juice-shop]="3000:3000"
LAB_DESC[juice-shop]="OWASP Juice Shop — Modern web security challenges (Node.js/Angular)"
LAB_MEM[juice-shop]="512m"

LAB_IMAGE[webgoat]="webgoat/webgoat"
LAB_PORT[webgoat]="8080:8080"
LAB_DESC[webgoat]="OWASP WebGoat — Interactive web security lessons"
LAB_MEM[webgoat]="512m"

LAB_IMAGE[hackazon]="ianwijaya/hackazon"
LAB_PORT[hackazon]="8085:80"
LAB_DESC[hackazon]="Hackazon — Vulnerable e-commerce platform for pen testing"
LAB_MEM[hackazon]="256m"

LAB_IMAGE[mutillidae]="citizenstig/nowasp"
LAB_PORT[mutillidae]="8086:80"
LAB_DESC[mutillidae]="OWASP Mutillidae II — Deliberately vulnerable web app"
LAB_MEM[mutillidae]="256m"

LAB_IMAGE[bwapp]="raesene/bwapp"
LAB_PORT[bwapp]="8087:80"
LAB_DESC[bwapp]="bWAPP — Buggy Web Application for testing"
LAB_MEM[bwapp]="256m"

LAB_IMAGE[vulnhub-metasploitable]="tleemcjr/metasploitable2"
LAB_PORT[vulnhub-metasploitable]="8089:80"
LAB_DESC[vulnhub-metasploitable]="Metasploitable 2 — Classic vulnerable Linux target"
LAB_MEM[vulnhub-metasploitable]="512m"

# Blue Team Labs
LAB_IMAGE[wazuh]="wazuh/wazuh-manager:latest"
LAB_PORT[wazuh]="1514:1514"
LAB_DESC[wazuh]="Wazuh SIEM — Open source security monitoring & threat detection"
LAB_MEM[wazuh]="1g"

LAB_IMAGE[thehive]="strangebee/thehive:5"
LAB_PORT[thehive]="9001:9000"
LAB_DESC[thehive]="TheHive — Security incident response platform"
LAB_MEM[thehive]="1g"

# ──────────────────────────────────────────────────────────────────

get_docker_compose() {
    if docker compose version &>/dev/null; then
        echo "docker compose"
    elif command -v docker-compose &>/dev/null; then
        echo "docker-compose"
    else
        echo ""
    fi
}

# Check if lab already exists in docker-compose.yml
lab_exists_in_compose() {
    local name="$1"
    grep -qE "^  ${name}:" "$COMPOSE_FILE" 2>/dev/null
}

# ─── LIST ─────────────────────────────────────────────────────────
cmd_list() {
    echo ""
    echo -e "  ${NEON_CYAN}${BOLD}╭──────────────────────────────────────────────────────────╮${NC}"
    echo -e "  ${NEON_CYAN}│${NC}  ${WHITE}${BOLD}📦 CYBERRANGE LAB CATALOG${NC}"
    echo -e "  ${NEON_CYAN}╰──────────────────────────────────────────────────────────╯${NC}"
    echo ""

    echo -e "  ${WHITE}${BOLD}AVAILABLE LABS (can be added):${NC}"
    echo -e "  ${MUTED}─────────────────────────────────────────────────────${NC}"
    for lab in "${!LAB_IMAGE[@]}"; do
        if lab_exists_in_compose "$lab"; then
            echo -e "  ${GREEN}✓ ${WHITE}${lab}${NC}  ${MUTED}(INSTALLED)${NC}  — ${LAB_DESC[$lab]}"
        else
            echo -e "  ${MUTED}○ ${WHITE}${lab}${NC}  ${YELLOW}(available)${NC} — ${LAB_DESC[$lab]}"
        fi
    done | sort

    echo ""
    echo -e "  ${WHITE}${BOLD}CORE SERVICES (always present):${NC}"
    echo -e "  ${MUTED}─────────────────────────────────────────────────────${NC}"
    echo -e "  ${GREEN}✓ ${WHITE}dvwa${NC}              — DVWA Web Exploitation Lab"
    echo -e "  ${GREEN}✓ ${WHITE}splunk${NC}            — Splunk Enterprise SIEM"
    echo -e "  ${GREEN}✓ ${WHITE}suricata${NC}          — Suricata Network IDS"
    echo -e "  ${GREEN}✓ ${WHITE}shuffle (4 svcs)${NC}  — Shuffle SOAR Platform"
    echo ""
    echo -e "  ${MUTED}Usage:  cyberrange lab add <name>   |  cyberrange lab remove <name>${NC}"
    echo ""
}

# ─── ADD ──────────────────────────────────────────────────────────
cmd_add() {
    local name="$1"

    if [[ -z "${LAB_IMAGE[$name]:-}" ]]; then
        echo -e "${RED}[!] Unknown lab: '$name'. Run 'cyberrange lab list' to see available labs.${NC}"
        exit 1
    fi

    if lab_exists_in_compose "$name"; then
        echo -e "${YELLOW}[!] Lab '$name' is already installed in docker-compose.yml${NC}"
        exit 0
    fi

    local image="${LAB_IMAGE[$name]}"
    local port="${LAB_PORT[$name]}"
    local mem="${LAB_MEM[$name]}"
    local desc="${LAB_DESC[$name]}"

    echo -e "${CYAN}[*] Adding lab: ${WHITE}${BOLD}$name${NC} ($desc)"

    # Insert before the 'volumes:' section at the bottom
    local service_block="
  ${name}:
    image: ${image}
    container_name: cyberrange_${name}
    ports:
      - \"${port}\"
    restart: unless-stopped
    mem_limit: ${mem}
"
    # Use sed to insert before the 'volumes:' line
    sed -i "/^volumes:/i\\${service_block}" "$COMPOSE_FILE"

    echo -e "${GREEN}[✓] Lab '${name}' added to docker-compose.yml${NC}"

    # Start the new service
    local compose_cmd
    compose_cmd=$(get_docker_compose)
    if [[ -n "$compose_cmd" ]]; then
        echo -e "${CYAN}[*] Pulling and starting ${name}...${NC}"
        (cd "$LAB_DIR" && $compose_cmd up -d "$name")
        echo -e "${GREEN}[✓] Lab '${name}' is now running!${NC}"
        echo -e "  → Access at: ${NEON_CYAN}http://$(hostname -I 2>/dev/null | awk '{print $1}'):${port%%:*}${NC}"
    fi
}

# ─── REMOVE ───────────────────────────────────────────────────────
cmd_remove() {
    local name="$1"

    # Prevent removing core services
    local core_services=("dvwa" "splunk" "suricata" "shuffle-frontend" "shuffle-backend" "shuffle-orborus" "shuffle-database")
    for core in "${core_services[@]}"; do
        if [[ "$name" == "$core" ]]; then
            echo -e "${RED}[!] Cannot remove core service '${name}'. Only addon labs can be removed.${NC}"
            exit 1
        fi
    done

    if ! lab_exists_in_compose "$name"; then
        echo -e "${YELLOW}[!] Lab '${name}' is not installed. Nothing to remove.${NC}"
        exit 0
    fi

    echo -e "${YELLOW}[*] Removing lab: ${WHITE}${BOLD}${name}${NC}"

    # Stop the container first
    local compose_cmd
    compose_cmd=$(get_docker_compose)
    if [[ -n "$compose_cmd" ]]; then
        (cd "$LAB_DIR" && $compose_cmd stop "$name" 2>/dev/null || true)
        (cd "$LAB_DIR" && $compose_cmd rm -f "$name" 2>/dev/null || true)
    fi

    # Remove the service block from docker-compose.yml
    # Match from "  <name>:" until the next service (line starting with "  " + word + ":") or "volumes:"
    python3 -c "
import re, sys

with open('$COMPOSE_FILE', 'r') as f:
    content = f.read()

# Pattern: match the service block including blank lines before next service
pattern = r'\n  ${name}:.*?(?=\n  [a-zA-Z]|\nvolumes:)'
content = re.sub(pattern, '', content, flags=re.DOTALL)

with open('$COMPOSE_FILE', 'w') as f:
    f.write(content)
"

    # Remove the Docker image to free disk space
    local image="${LAB_IMAGE[$name]:-}"
    if [[ -n "$image" ]]; then
        echo -e "${CYAN}[*] Removing Docker image: ${image}...${NC}"
        docker rmi "$image" 2>/dev/null || true
    fi

    echo -e "${GREEN}[✓] Lab '${name}' removed successfully! Image cleaned up.${NC}"
}

# ─── MAIN ─────────────────────────────────────────────────────────
case "${1:-}" in
    list|ls)
        cmd_list
        ;;
    add|install)
        if [[ -z "${2:-}" ]]; then
            echo -e "${RED}Usage: cyberrange lab add <lab-name>${NC}"
            echo -e "${MUTED}Run 'cyberrange lab list' to see available labs.${NC}"
            exit 1
        fi
        cmd_add "$2"
        ;;
    remove|rm|uninstall)
        if [[ -z "${2:-}" ]]; then
            echo -e "${RED}Usage: cyberrange lab remove <lab-name>${NC}"
            exit 1
        fi
        cmd_remove "$2"
        ;;
    *)
        echo -e "${WHITE}${BOLD}CyberRange 2.0 Lab Manager${NC}"
        echo -e ""
        echo -e "  ${CYAN}cyberrange lab list${NC}            Show all available and installed labs"
        echo -e "  ${CYAN}cyberrange lab add <name>${NC}      Install and start a new lab"
        echo -e "  ${CYAN}cyberrange lab remove <name>${NC}   Stop, remove, and clean up a lab"
        echo ""
        ;;
esac
