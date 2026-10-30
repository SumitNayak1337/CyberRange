#!/usr/bin/env bash
# ==============================================================================
#   CYBERRANGE 2.0 // CLEAN TERMINAL MOTD & ENDPOINT DIRECTORY
#   No ASCII art font bloat — Fast, crisp, functional SSH terminal login
# ==============================================================================

# Terminal Colors
NC='\033[0m'
BOLD='\033[1m'
CYAN='\033[0;36m'
NEON_CYAN='\033[38;5;51m'
NEON_AQUA='\033[38;5;49m'
NEON_GREEN='\033[38;5;48m'
BRIGHT_GREEN='\033[38;5;46m'
GOLD='\033[38;5;220m'
NEON_RED='\033[38;5;196m'
MAGENTA='\033[38;5;201m'
WHITE='\033[1;37m'
MUTED='\033[38;5;244m'

# Auto-Detect Host IP
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
echo -e "${NEON_CYAN}══════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}${BOLD}  CYBERRANGE 2.0 // SOC SIMULATION LAB (12GB RAM · 60GB DISK)${NC}"
echo -e "${NEON_CYAN}══════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "  ${WHITE}🌐 HOST IP ADDRESS :${NC} ${GOLD}${BOLD}${IP}${NC}"
echo -e "  ${WHITE}🛡️  WEB DASHBOARD   :${NC} ${NEON_AQUA}${BOLD}http://${IP}:9000${NC}"
echo -e "  ${MUTED}────────────────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${NEON_RED}${BOLD}🔴 RED TEAM (Target)${NC}"
echo -e "    • ${WHITE}DVWA Web App${NC}     → ${NEON_AQUA}http://${IP}:8081${NC}  ${MUTED}[admin / password]${NC}"
echo -e "  ${MUTED}────────────────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${NEON_CYAN}${BOLD}🔵 BLUE TEAM (SIEM & Detection)${NC}"
echo -e "    • ${WHITE}Splunk SIEM${NC}      → ${NEON_AQUA}http://${IP}:8000${NC}  ${MUTED}[admin / CyberRange@123]${NC}"
echo -e "    • ${WHITE}Splunk HEC${NC}       → ${NEON_AQUA}http://${IP}:8088${NC}  ${MUTED}[HTTP Event Collector]${NC}"
echo -e "    • ${WHITE}Suricata NIDS${NC}    → ${BRIGHT_GREEN}ACTIVE (Host Mode)${NC} ${MUTED}[/var/log/suricata/eve.json]${NC}"
echo -e "  ${MUTED}────────────────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${MAGENTA}${BOLD}⚡ SOAR (Automation & Response)${NC}"
echo -e "    • ${WHITE}Shuffle SOAR${NC}     → ${NEON_AQUA}http://${IP}:3443${NC}  ${MUTED}[admin / CyberRange@123]${NC}"
echo -e "    • ${WHITE}Shuffle API${NC}      → ${NEON_AQUA}http://${IP}:5001${NC}  ${MUTED}[Backend API]${NC}"
echo -e "  ${MUTED}────────────────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${WHITE}${BOLD}COMMANDS:${NC} ${CYAN}cyberrange status${NC} | ${CYAN}start${NC} | ${CYAN}stop${NC} | ${CYAN}restart${NC} | ${CYAN}fix${NC}"
echo -e "${NEON_CYAN}══════════════════════════════════════════════════════════════════════════════${NC}"
echo ""
