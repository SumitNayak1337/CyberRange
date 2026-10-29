#!/usr/bin/env bash
# ==============================================================================
#   CYBERRANGE 2.0 // ASCII MAGIC MOTD & LOGIN BANNER
# ==============================================================================

# Neon & Cyber Colors
NC='\033[0m'
BOLD='\033[1m'
NEON_CYAN='\033[38;5;51m'
NEON_AQUA='\033[38;5;49m'
NEON_GREEN='\033[38;5;48m'
BRIGHT_GREEN='\033[38;5;46m'
ELECTRIC_GREEN='\033[1;32m'
GOLD='\033[38;5;220m'
NEON_RED='\033[38;5;196m'
WHITE='\033[1;37m'
MUTED='\033[38;5;244m'

# Detect IP
detect_ip() {
    local ip=""
    ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || true)
    if [[ -z "$ip" || "$ip" =~ ^169\.254 ]]; then
        ip=$(ip -4 addr show ens33 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1 || true)
    fi
    if [[ -z "$ip" || "$ip" =~ ^169\.254 ]]; then
        for iface in $(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -v 'lo\|docker\|br-\|veth'); do
            cand=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1 || true)
            if [[ -n "$cand" && ! "$cand" =~ ^169\.254 && ! "$cand" =~ ^127\. ]]; then
                ip="$cand"
                break
            fi
        done
    fi
    if [[ -z "$ip" || "$ip" =~ ^169\.254 ]]; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
    fi
    [[ -z "$ip" || "$ip" =~ ^169\.254 ]] && ip="127.0.0.1"
    echo "$ip"
}

IP=$(detect_ip)

echo ""
echo -e "${NEON_CYAN}   ______      __             ____                          ___     ____  ${NC}"
echo -e "${NEON_AQUA}  / ____/_  __/ /_  ___  ____/ __ \\____ _____  ____ ____   |__ \\   / __ \\ ${NC}"
echo -e "${NEON_GREEN} / /   / / / / __ \\/ _ \\/ __/ /_/ / __ \`/ __ \\/ __ \`/ _ \\  __/ /  / / / / ${NC}"
echo -e "${BRIGHT_GREEN}/ /___/ /_/ / /_/ /  __/ / / _, _/ /_/ / / / / /_/ /  __/ / __/_ / /_/ /  ${NC}"
echo -e "${ELECTRIC_GREEN}\\____/\\__, /_.___/\\___/_/ /_/ |_|\\__,_/_/ /_/\\__, /\\___/ /____/(_)____/   ${NC}"
echo -e "${MUTED}     /____/                                 /____/                        ${NC}"
echo -e "       ${BOLD}${WHITE}S E C U R I T Y   O P E R A T I O N S   C E N T E R   L A B${NC}"
echo -e "       ${MUTED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${NEON_CYAN}╭────────────────────────────────────────────────────────────────────────────╮${NC}"
echo -e "  ${NEON_CYAN}│${NC}  ${WHITE}🌐 HOST IP ADDRESS :${NC} ${GOLD}${BOLD}${IP}${NC}"
echo -e "  ${NEON_CYAN}│${NC}  ${WHITE}🛡️  WEB DASHBOARD   :${NC} ${NEON_AQUA}${BOLD}http://${IP}:9000${NC}"
echo -e "  ${NEON_CYAN}├────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "  ${NEON_CYAN}│${NC}  ${NEON_RED}${BOLD}🔴 RED TEAM (Attacker Targets)${NC}"
echo -e "  ${NEON_CYAN}│${NC}    • ${WHITE}DVWA Web App${NC}     → ${NEON_AQUA}http://${IP}:8081${NC}  ${MUTED}[admin / password]${NC}"
echo -e "  ${NEON_CYAN}│${NC}    ${MUTED}Add more labs: cyberrange lab list${NC}"
echo -e "  ${NEON_CYAN}├────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "  ${NEON_CYAN}│${NC}  ${NEON_CYAN}${BOLD}🔵 BLUE TEAM (Defense & SIEM)${NC}"
echo -e "  ${NEON_CYAN}│${NC}    • ${WHITE}Splunk SIEM${NC}      → ${NEON_AQUA}http://${IP}:8000${NC}  ${MUTED}[admin / CyberRange@123]${NC}"
echo -e "  ${NEON_CYAN}│${NC}    • ${WHITE}Splunk HEC${NC}       → ${NEON_AQUA}http://${IP}:8088${NC}  ${MUTED}[HTTP Event Collector]${NC}"
echo -e "  ${NEON_CYAN}│${NC}    • ${WHITE}Suricata NIDS${NC}    → ${BRIGHT_GREEN}ACTIVE (Host Mode)${NC} ${MUTED}[/var/log/suricata]${NC}"
echo -e "  ${NEON_CYAN}├────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "  ${NEON_CYAN}│${NC}  ${GOLD}${BOLD}⚡ QUICK MANAGEMENT COMMANDS${NC}"
echo -e "  ${NEON_CYAN}│${NC}    ${WHITE}cyberrange status${NC}   ${MUTED}│${NC} Check live container health & resources"
echo -e "  ${NEON_CYAN}│${NC}    ${WHITE}cyberrange fix${NC}      ${MUTED}│${NC} Self-healing auto-repair & disk expander"
echo -e "  ${NEON_CYAN}│${NC}    ${WHITE}cyberrange stop${NC}     ${MUTED}│${NC} Gracefully shutdown lab containers"
echo -e "  ${NEON_CYAN}│${NC}    ${WHITE}cyberrange restart${NC}  ${MUTED}│${NC} Quick restart all services"
echo -e "  ${NEON_CYAN}╰────────────────────────────────────────────────────────────────────────────╯${NC}"
echo ""
