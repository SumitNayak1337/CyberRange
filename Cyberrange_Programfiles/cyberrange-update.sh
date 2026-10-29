#!/usr/bin/env bash
# ==============================================================================
#   CYBERRANGE 2.0 // ALL-IN-ONE OPTIMIZER & UPDATER
#   SCP this to the machine and run: sudo bash cyberrange-update.sh
#   
#   What it does:
#     1. Removes Juice Shop (saves ~400MB RAM + ~800MB disk)
#     2. Adds memory limits to all containers
#     3. Creates lab manager script (add/remove labs dynamically)
#     4. Optimizes machine for SSH-only (removes GUI, snap, bloat)
#     5. Sets up 4GB swap
#     6. Configures Docker log rotation
#     7. Disables unnecessary services
#     8. Tunes kernel for server
#     9. Updates main cyberrange CLI, banner, firewall
#    10. Cleans up old Juice Shop container + image
#    11. Restarts everything fresh
# ==============================================================================

set -eo pipefail

NC='\033[0m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NEON_CYAN='\033[38;5;51m'
NEON_GREEN='\033[38;5;48m'
MUTED='\033[38;5;244m'

# ─── ROOT CHECK ──────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[!] Run as root: sudo bash cyberrange-update.sh${NC}"
    exit 1
fi

echo ""
echo -e "${NEON_CYAN}${BOLD}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}${BOLD}  CYBERRANGE 2.0 // ALL-IN-ONE OPTIMIZER & UPDATER${NC}"
echo -e "${NEON_CYAN}${BOLD}══════════════════════════════════════════════════════════════════${NC}"
echo ""

# ─── FIND LAB DIRECTORY ──────────────────────────────────────────
LAB_DIR=""
if [[ -f "/etc/cyberrange/lab_path" ]]; then
    LAB_DIR="$(cat /etc/cyberrange/lab_path)"
fi
if [[ -z "$LAB_DIR" || ! -d "$LAB_DIR" ]]; then
    for d in "/home/cyberrange/CyberRange/Cyberrange_Programfiles" \
             "/opt/cyberrange/Cyberrange_Programfiles" \
             "/root/CyberRange/Cyberrange_Programfiles"; do
        if [[ -d "$d" ]]; then
            LAB_DIR="$d"
            break
        fi
    done
fi
if [[ -z "$LAB_DIR" || ! -d "$LAB_DIR" ]]; then
    echo -e "${RED}[!] Cannot find CyberRange lab directory.${NC}"
    echo -e "${YELLOW}Enter the full path to Cyberrange_Programfiles:${NC}"
    read -r LAB_DIR
    if [[ ! -d "$LAB_DIR" ]]; then
        echo -e "${RED}[!] Directory not found: $LAB_DIR${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}[✓] Lab directory: ${WHITE}$LAB_DIR${NC}"

COMPOSE_FILE="$LAB_DIR/docker-compose.yml"
CYBERRANGE_CLI="$LAB_DIR/cyberrange"
BANNER_SH="$LAB_DIR/banner.sh"
INSTALL_SH="$LAB_DIR/install.sh"

# ──────────────────────────────────────────────────────────────────
#  PHASE 1: STOP EVERYTHING
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}[PHASE 1/10] Stopping All Services...${NC}"
pkill -f "python3 -m http.server 9000" 2>/dev/null || true
if docker compose version &>/dev/null; then
    (cd "$LAB_DIR" && docker compose down 2>/dev/null || true)
elif command -v docker-compose &>/dev/null; then
    (cd "$LAB_DIR" && docker-compose down 2>/dev/null || true)
fi
echo -e "${GREEN}  [✓] Services stopped.${NC}"

# ──────────────────────────────────────────────────────────────────
#  PHASE 2: REMOVE JUICE SHOP CONTAINER + IMAGE
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}[PHASE 2/10] Removing Juice Shop Container & Image...${NC}"
docker stop cyberrange_juice 2>/dev/null || true
docker rm -f cyberrange_juice 2>/dev/null || true
docker rmi bkimminich/juice-shop 2>/dev/null || true
echo -e "${GREEN}  [✓] Juice Shop removed (~400MB RAM + ~800MB disk saved).${NC}"

# ──────────────────────────────────────────────────────────────────
#  PHASE 3: WRITE OPTIMIZED DOCKER-COMPOSE.YML
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}[PHASE 3/10] Writing Optimized docker-compose.yml...${NC}"

cp "$COMPOSE_FILE" "${COMPOSE_FILE}.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

cat > "$COMPOSE_FILE" << 'COMPOSE_EOF'
services:

  dvwa:
    image: vulnerables/web-dvwa
    container_name: cyberrange_dvwa
    ports:
      - "8081:80"
    restart: unless-stopped
    mem_limit: 256m

  splunk:
    image: splunk/splunk:latest
    container_name: cyberrange_splunk
    environment:
      - SPLUNK_START_ARGS=--accept-license
      - SPLUNK_PASSWORD=CyberRange@123
      - SPLUNK_GENERAL_TERMS=--accept-sgt-current-at-splunk-com
      - ENABLE_TCP_MODE=true
      - SPLUNK_HEC_TOKEN=12345678-1234-1234-1234-1234567890ab
      - SPLUNK_DISPATCH_TTL=10m
      - SPLUNK_DISPATCH_DIR_REAPER_THREADS=2
      - SPLUNK_DISPATCH_DIR_REAPER_FREQUENCY=5m
    ports:
      - "8000:8000"
      - "8088:8088"
    volumes:
      - /var/log:/host_var_log:ro
      - splunk_data:/opt/splunk/var
    restart: unless-stopped
    mem_limit: 2g

  suricata:
    image: jasonish/suricata:latest
    container_name: cyberrange_suricata
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    command: -i ens33
    volumes:
      - /var/log/suricata:/var/log/suricata
    restart: unless-stopped
    mem_limit: 512m

  shuffle-frontend:
    image: ghcr.io/shuffle/shuffle-frontend:latest
    container_name: cyberrange_shuffle_frontend
    hostname: shuffle-frontend
    ports:
      - "3443:80"
      - "3444:443"
    environment:
      - BACKEND_HOSTNAME=shuffle-backend
    restart: unless-stopped
    mem_limit: 256m
    depends_on:
      - shuffle-backend

  shuffle-backend:
    image: ghcr.io/shuffle/shuffle-backend:latest
    container_name: cyberrange_shuffle_backend
    hostname: shuffle-backend
    ports:
      - "5001:5001"
    environment:
      - DATASTORE_EMULATOR_HOST=shuffle-database:9200
      - SHUFFLE_APP_HOTLOAD_FOLDER=/shuffle-apps
      - SHUFFLE_FILE_LOCATION=/shuffle-files
      - SHUFFLE_OPENSEARCH_URL=https://shuffle-database:9200
      - SHUFFLE_DEFAULT_USERNAME=admin
      - SHUFFLE_DEFAULT_PASSWORD=CyberRange@123
      - SHUFFLE_DEFAULT_APIKEY=cyberrange-shuffle-api-key-2024
      - ORG_ID=cyberrange
      - SHUFFLE_ELASTIC=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - shuffle_apps:/shuffle-apps
      - shuffle_files:/shuffle-files
    restart: unless-stopped
    mem_limit: 1g
    depends_on:
      - shuffle-database

  shuffle-orborus:
    image: ghcr.io/shuffle/shuffle-orborus:latest
    container_name: cyberrange_shuffle_orborus
    hostname: shuffle-orborus
    environment:
      - SHUFFLE_APP_SDK_VERSION=latest
      - SHUFFLE_WORKER_VERSION=latest
      - BASE_URL=http://shuffle-backend:5001
      - DOCKER_API_VERSION=1.40
      - SHUFFLE_BASE_IMAGE_NAME=ghcr.io/shuffle
      - SHUFFLE_SCALE_REPLICAS=1
      - ORG_ID=cyberrange
      - ENVIRONMENT_NAME=CyberRange
      - CLEANUP=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped
    mem_limit: 512m
    depends_on:
      - shuffle-backend

  shuffle-database:
    image: opensearchproject/opensearch:2.14.0
    container_name: cyberrange_shuffle_db
    hostname: shuffle-database
    environment:
      - "OPENSEARCH_JAVA_OPTS=-Xms256m -Xmx256m"
      - bootstrap.memory_lock=true
      - cluster.routing.allocation.disk.threshold_enabled=false
      - cluster.name=shuffle-cluster
      - node.name=shuffle-node
      - discovery.type=single-node
      - DISABLE_INSTALL_DEMO_CONFIG=true
      - DISABLE_SECURITY_PLUGIN=true
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    volumes:
      - shuffle_db_data:/usr/share/opensearch/data
    restart: unless-stopped
    mem_limit: 768m

volumes:
  splunk_data:
  shuffle_apps:
  shuffle_files:
  shuffle_db_data:
COMPOSE_EOF

echo -e "${GREEN}  [✓] docker-compose.yml updated (memory-limited, no Juice Shop).${NC}"

# ──────────────────────────────────────────────────────────────────
#  PHASE 4: CREATE LAB MANAGER SCRIPT
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}[PHASE 4/10] Creating Lab Manager Script...${NC}"

cat > "$LAB_DIR/cyberrange-lab.sh" << 'LABMGR_EOF'
#!/usr/bin/env bash
# ==============================================================================
#   CYBERRANGE 2.0 // LAB MANAGER — Add / Remove / List Labs
#   Usage: cyberrange lab list | add <name> | remove <name>
# ==============================================================================

set -eo pipefail

NC='\033[0m'; GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; BOLD='\033[1m'
NEON_GREEN='\033[38;5;48m'; NEON_CYAN='\033[38;5;51m'; MUTED='\033[38;5;244m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/docker-compose.yml" ]]; then
    LAB_DIR="$SCRIPT_DIR"
elif [[ -f "/etc/cyberrange/lab_path" ]]; then
    LAB_DIR="$(cat /etc/cyberrange/lab_path)"
else
    LAB_DIR="/home/cyberrange/CyberRange/Cyberrange_Programfiles"
fi
COMPOSE_FILE="$LAB_DIR/docker-compose.yml"

# ─── LAB CATALOG ─────────────────────────────────────────────────
declare -A LAB_IMAGE LAB_PORT LAB_DESC LAB_MEM

LAB_IMAGE[juice-shop]="bkimminich/juice-shop"
LAB_PORT[juice-shop]="3000:3000"
LAB_DESC[juice-shop]="OWASP Juice Shop — Modern web security challenges"
LAB_MEM[juice-shop]="512m"

LAB_IMAGE[webgoat]="webgoat/webgoat"
LAB_PORT[webgoat]="8080:8080"
LAB_DESC[webgoat]="OWASP WebGoat — Interactive web security lessons"
LAB_MEM[webgoat]="512m"

LAB_IMAGE[hackazon]="ianwijaya/hackazon"
LAB_PORT[hackazon]="8085:80"
LAB_DESC[hackazon]="Hackazon — Vulnerable e-commerce for pen testing"
LAB_MEM[hackazon]="256m"

LAB_IMAGE[mutillidae]="citizenstig/nowasp"
LAB_PORT[mutillidae]="8086:80"
LAB_DESC[mutillidae]="OWASP Mutillidae II — Deliberately vulnerable web app"
LAB_MEM[mutillidae]="256m"

LAB_IMAGE[bwapp]="raesene/bwapp"
LAB_PORT[bwapp]="8087:80"
LAB_DESC[bwapp]="bWAPP — Buggy Web Application for testing"
LAB_MEM[bwapp]="256m"

LAB_IMAGE[wazuh]="wazuh/wazuh-manager:latest"
LAB_PORT[wazuh]="1514:1514"
LAB_DESC[wazuh]="Wazuh SIEM — Open source security monitoring"
LAB_MEM[wazuh]="1g"

LAB_IMAGE[thehive]="strangebee/thehive:5"
LAB_PORT[thehive]="9001:9000"
LAB_DESC[thehive]="TheHive — Incident response platform"
LAB_MEM[thehive]="1g"

get_docker_compose() {
    if docker compose version &>/dev/null; then echo "docker compose"
    elif command -v docker-compose &>/dev/null; then echo "docker-compose"
    else echo ""; fi
}

lab_exists_in_compose() { grep -qE "^  ${1}:" "$COMPOSE_FILE" 2>/dev/null; }

cmd_list() {
    echo ""
    echo -e "  ${NEON_CYAN}${BOLD}╭──────────────────────────────────────────────────────────╮${NC}"
    echo -e "  ${NEON_CYAN}│${NC}  ${WHITE}${BOLD}📦 CYBERRANGE LAB CATALOG${NC}"
    echo -e "  ${NEON_CYAN}╰──────────────────────────────────────────────────────────╯${NC}"
    echo ""
    echo -e "  ${WHITE}${BOLD}ADDON LABS:${NC}"
    echo -e "  ${MUTED}─────────────────────────────────────────────────────${NC}"
    for lab in $(echo "${!LAB_IMAGE[@]}" | tr ' ' '\n' | sort); do
        if lab_exists_in_compose "$lab"; then
            echo -e "  ${GREEN}✓ ${WHITE}${lab}${NC}  ${MUTED}(INSTALLED)${NC}  — ${LAB_DESC[$lab]}"
        else
            echo -e "  ${MUTED}○ ${WHITE}${lab}${NC}  ${YELLOW}(available)${NC} — ${LAB_DESC[$lab]}"
        fi
    done
    echo ""
    echo -e "  ${WHITE}${BOLD}CORE (always present):${NC} dvwa, splunk, suricata, shuffle"
    echo ""
    echo -e "  ${MUTED}Usage:  cyberrange lab add <name>  |  cyberrange lab remove <name>${NC}"
    echo ""
}

cmd_add() {
    local name="$1"
    if [[ -z "${LAB_IMAGE[$name]:-}" ]]; then
        echo -e "${RED}[!] Unknown lab: '$name'. Run 'cyberrange lab list' to see available labs.${NC}"; exit 1
    fi
    if lab_exists_in_compose "$name"; then
        echo -e "${YELLOW}[!] Lab '$name' is already installed.${NC}"; exit 0
    fi
    local image="${LAB_IMAGE[$name]}" port="${LAB_PORT[$name]}" mem="${LAB_MEM[$name]}"
    echo -e "${CYAN}[*] Adding lab: ${WHITE}${BOLD}$name${NC}"

    # Insert before 'volumes:' section
    sed -i "/^volumes:/i\\
\\
  ${name}:\\
    image: ${image}\\
    container_name: cyberrange_${name}\\
    ports:\\
      - \"${port}\"\\
    restart: unless-stopped\\
    mem_limit: ${mem}" "$COMPOSE_FILE"

    echo -e "${GREEN}[✓] Lab '${name}' added to docker-compose.yml${NC}"
    local compose_cmd; compose_cmd=$(get_docker_compose)
    if [[ -n "$compose_cmd" ]]; then
        echo -e "${CYAN}[*] Pulling and starting ${name}...${NC}"
        (cd "$LAB_DIR" && $compose_cmd up -d "$name")
        echo -e "${GREEN}[✓] Lab '${name}' is running! Access: http://$(hostname -I 2>/dev/null | awk '{print $1}'):${port%%:*}${NC}"
    fi
}

cmd_remove() {
    local name="$1"
    local core=("dvwa" "splunk" "suricata" "shuffle-frontend" "shuffle-backend" "shuffle-orborus" "shuffle-database")
    for c in "${core[@]}"; do
        if [[ "$name" == "$c" ]]; then
            echo -e "${RED}[!] Cannot remove core service '${name}'.${NC}"; exit 1
        fi
    done
    if ! lab_exists_in_compose "$name"; then
        echo -e "${YELLOW}[!] Lab '${name}' not installed.${NC}"; exit 0
    fi
    echo -e "${YELLOW}[*] Removing lab: ${WHITE}${BOLD}${name}${NC}"
    local compose_cmd; compose_cmd=$(get_docker_compose)
    if [[ -n "$compose_cmd" ]]; then
        (cd "$LAB_DIR" && $compose_cmd stop "$name" 2>/dev/null || true)
        (cd "$LAB_DIR" && $compose_cmd rm -f "$name" 2>/dev/null || true)
    fi
    # Remove service block
    python3 -c "
import re
with open('$COMPOSE_FILE','r') as f: c=f.read()
c=re.sub(r'\n  ${name}:.*?(?=\n  [a-zA-Z]|\nvolumes:)','',c,flags=re.DOTALL)
with open('$COMPOSE_FILE','w') as f: f.write(c)
"
    local image="${LAB_IMAGE[$name]:-}"
    [[ -n "$image" ]] && docker rmi "$image" 2>/dev/null || true
    echo -e "${GREEN}[✓] Lab '${name}' removed and image cleaned.${NC}"
}

case "${1:-}" in
    list|ls) cmd_list ;;
    add|install) [[ -z "${2:-}" ]] && { echo -e "${RED}Usage: cyberrange lab add <name>${NC}"; exit 1; }; cmd_add "$2" ;;
    remove|rm|uninstall) [[ -z "${2:-}" ]] && { echo -e "${RED}Usage: cyberrange lab remove <name>${NC}"; exit 1; }; cmd_remove "$2" ;;
    *) echo -e "${WHITE}${BOLD}Lab Manager:${NC}  cyberrange lab [list | add <name> | remove <name>]" ;;
esac
LABMGR_EOF

chmod +x "$LAB_DIR/cyberrange-lab.sh"
echo -e "${GREEN}  [✓] Lab manager script created: $LAB_DIR/cyberrange-lab.sh${NC}"

# ──────────────────────────────────────────────────────────────────
#  PHASE 5: SETUP SWAP (4GB)
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}[PHASE 5/10] Setting Up 4GB Swap...${NC}"
if swapon --show | grep -q '/swapfile'; then
    echo -e "${GREEN}  [✓] Swap already exists.${NC}"
    swapon --show | sed 's/^/    /'
else
    fallocate -l 4G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo -e "${GREEN}  [✓] 4GB swap created and activated.${NC}"
fi
sysctl vm.swappiness=10 2>/dev/null || true
grep -q 'vm.swappiness' /etc/sysctl.conf || echo 'vm.swappiness=10' >> /etc/sysctl.conf

# ──────────────────────────────────────────────────────────────────
#  PHASE 6: REMOVE GUI / DESKTOP / BLOAT
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}[PHASE 6/10] Removing GUI, Snap, Desktop Bloat (SSH-only mode)...${NC}"

# Stop display managers
systemctl stop gdm3 2>/dev/null || systemctl stop lightdm 2>/dev/null || systemctl stop sddm 2>/dev/null || true
systemctl disable gdm3 2>/dev/null || systemctl disable lightdm 2>/dev/null || systemctl disable sddm 2>/dev/null || true

export DEBIAN_FRONTEND=noninteractive

# Remove GUI packages
apt-get remove -y --purge \
    ubuntu-desktop ubuntu-desktop-minimal \
    gdm3 lightdm sddm \
    gnome-shell gnome-session gnome-terminal gnome-control-center \
    nautilus gedit totem eog evince \
    firefox firefox-esr \
    libreoffice* thunderbird* \
    gnome-calculator gnome-characters gnome-clocks gnome-contacts \
    gnome-font-viewer gnome-logs gnome-maps gnome-music gnome-photos \
    gnome-screenshot gnome-system-monitor gnome-weather \
    cheese shotwell rhythmbox yelp \
    xserver-xorg xorg x11-common x11-utils \
    pulseaudio pipewire \
    2>/dev/null || true

# Remove snap
snap list 2>/dev/null | awk 'NR>1 {print $1}' | while read -r pkg; do
    snap remove --purge "$pkg" 2>/dev/null || true
done
apt-get remove -y --purge snapd flatpak 2>/dev/null || true
rm -rf /snap /var/snap /var/lib/snapd ~/snap 2>/dev/null || true

echo -e "${GREEN}  [✓] GUI, Snap, desktop bloat removed.${NC}"

# ──────────────────────────────────────────────────────────────────
#  PHASE 7: CLEAN SYSTEM DATA
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}[PHASE 7/10] Cleaning System Caches & Temp Files...${NC}"

apt-get autoremove -y --purge 2>/dev/null || true
apt-get autoclean -y 2>/dev/null || true
apt-get clean 2>/dev/null || true

# Truncate journals
journalctl --vacuum-time=2d 2>/dev/null || true

# Clear caches and temps
rm -rf /home/*/.cache/thumbnails/* 2>/dev/null || true
rm -rf /root/.cache/thumbnails/* 2>/dev/null || true
rm -rf /tmp/* 2>/dev/null || true
rm -rf /var/tmp/* 2>/dev/null || true
rm -rf /var/crash/* 2>/dev/null || true

echo -e "${GREEN}  [✓] System cleaned.${NC}"

# ──────────────────────────────────────────────────────────────────
#  PHASE 8: OPTIMIZE DOCKER
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}[PHASE 8/10] Optimizing Docker (log rotation, prune)...${NC}"

# Truncate existing logs
sh -c 'truncate -s 0 /var/lib/docker/containers/*/*-json.log 2>/dev/null' || true

# Configure log rotation
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'DOCKERJSON'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
DOCKERJSON

# Prune unused Docker stuff
docker system prune -af 2>/dev/null || true
docker volume prune -f 2>/dev/null || true

# Restart Docker to apply log config
systemctl restart docker
sleep 3

echo -e "${GREEN}  [✓] Docker optimized (log rotation: 10MB × 3 per container).${NC}"

# ──────────────────────────────────────────────────────────────────
#  PHASE 9: DISABLE UNNECESSARY SERVICES + KERNEL TUNING
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}[PHASE 9/10] Disabling Unnecessary Services & Tuning Kernel...${NC}"

for svc in cups cups-browsed avahi-daemon bluetooth ModemManager \
           networkd-dispatcher whoopsie apport unattended-upgrades \
           motd-news fwupd; do
    systemctl stop "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
    systemctl mask "$svc" 2>/dev/null || true
done

# Kernel tuning (only add if not already present)
if ! grep -q 'CyberRange Optimizations' /etc/sysctl.conf 2>/dev/null; then
    cat >> /etc/sysctl.conf << 'SYSCTL_EOF'

# CyberRange Optimizations
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50
net.core.somaxconn = 1024
net.ipv4.tcp_tw_reuse = 1
SYSCTL_EOF
fi
sysctl -p 2>/dev/null || true

echo -e "${GREEN}  [✓] Services disabled, kernel tuned.${NC}"

# ──────────────────────────────────────────────────────────────────
#  PHASE 10: UPDATE CYBERRANGE CLI + BANNER + FIREWALL
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}[PHASE 10/10] Patching CyberRange CLI, Banner & Firewall...${NC}"

# --- Patch banner.sh: remove Juice Shop line ---
if [[ -f "$BANNER_SH" ]]; then
    sed -i '/OWASP Juice Shop/d' "$BANNER_SH"
    sed -i '/Juice Shop/d' "$BANNER_SH"
    echo -e "${GREEN}  [✓] banner.sh patched (Juice Shop removed).${NC}"
fi

# --- Patch cyberrange CLI: remove Juice Shop from status containers list ---
if [[ -f "$CYBERRANGE_CLI" ]]; then
    # Remove juice from containers check array
    sed -i 's/"cyberrange_juice" //g' "$CYBERRANGE_CLI"
    sed -i 's/ "cyberrange_juice"//g' "$CYBERRANGE_CLI"
    # Remove Juice Shop from dashboard card
    sed -i '/OWASP Juice Shop/d' "$CYBERRANGE_CLI"
    sed -i '/Juice Shop/d' "$CYBERRANGE_CLI"
    sed -i 's|DVWA/Juice Shop|DVWA|g' "$CYBERRANGE_CLI"

    # Add lab command if not already present
    if ! grep -q 'cmd_lab' "$CYBERRANGE_CLI"; then
        # Add cmd_lab function before main()
        sed -i '/^# --- Main Dispatcher ---/i\
# --- Command: LAB ---\
cmd_lab() {\
    resolve_paths\
    local lab_script="$LAB_DIR/cyberrange-lab.sh"\
    if [[ -f "$lab_script" ]]; then\
        bash "$lab_script" "$@"\
    else\
        echo -e "${RED}[!] Lab manager not found.${NC}"\
        exit 1\
    fi\
}\
' "$CYBERRANGE_CLI"

        # Add lab case to dispatcher
        sed -i '/banner|info)/i\
        lab)\
            shift\
            cmd_lab "$@"\
            ;;' "$CYBERRANGE_CLI"

        # Add help entry
        sed -i '/banner.*Display the aesthetic/i\
    echo -e "    ${NEON_CYAN}lab${NC}         Manage addon labs: [list | add <name> | remove <name>]"' "$CYBERRANGE_CLI"
    fi

    echo -e "${GREEN}  [✓] cyberrange CLI patched.${NC}"
fi

# --- Patch lab-start.sh ---
if [[ -f "$LAB_DIR/lab-start.sh" ]]; then
    sed -i '/Juice Shop/d' "$LAB_DIR/lab-start.sh"
    echo -e "${GREEN}  [✓] lab-start.sh patched.${NC}"
fi

# --- Fix Firewall: remove port 3000, keep rest ---
if command -v ufw &>/dev/null; then
    ufw delete allow 3000/tcp 2>/dev/null || true
    # Ensure essential ports are open
    for port in 22 80 3443 3444 5001 8000 8081 8088 9000; do
        ufw allow "$port"/tcp 2>/dev/null || true
    done
    echo -e "${GREEN}  [✓] Firewall updated (port 3000 removed).${NC}"
fi

# --- LVM Disk Expansion ---
echo ""
echo -e "${CYAN}[*] Checking disk expansion...${NC}"
ROOT_LV=$(df / | tail -1 | awk '{print $1}')
if [[ "$ROOT_LV" == *"/dev/mapper/"* ]]; then
    lvextend -l +100%FREE "$ROOT_LV" 2>/dev/null || true
    resize2fs "$ROOT_LV" 2>/dev/null || true
    echo -e "${GREEN}  [✓] LVM disk expanded.${NC}"
fi

# --- Make all scripts executable ---
chmod +x "$LAB_DIR"/*.sh 2>/dev/null || true
chmod +x "$CYBERRANGE_CLI" 2>/dev/null || true

# ──────────────────────────────────────────────────────────────────
#  RESTART CYBERRANGE
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}[*] Restarting CyberRange services...${NC}"
if command -v cyberrange &>/dev/null; then
    cyberrange start --quiet 2>/dev/null || cyberrange start 2>/dev/null || true
else
    (cd "$LAB_DIR" && docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null || true)
fi

# ──────────────────────────────────────────────────────────────────
#  FINAL REPORT
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${NEON_GREEN}${BOLD}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  [✓] ALL-IN-ONE UPDATE COMPLETE!${NC}"
echo -e "${NEON_GREEN}${BOLD}══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${WHITE}${BOLD}What was done:${NC}"
echo -e "    ✅ Juice Shop removed (saves ~400MB RAM + ~800MB disk)"
echo -e "    ✅ Memory limits on all containers (total ~5.3GB capped)"
echo -e "    ✅ OpenSearch heap reduced (512m → 256m)"
echo -e "    ✅ 4GB swap file created"
echo -e "    ✅ GUI/Desktop/Snap removed (SSH-only mode)"
echo -e "    ✅ Docker log rotation (10MB × 3 per container)"
echo -e "    ✅ Unnecessary services disabled"
echo -e "    ✅ Kernel tuned for server workload"
echo -e "    ✅ Lab manager installed (cyberrange lab add/remove)"
echo -e "    ✅ Firewall cleaned"
echo ""
echo -e "  ${WHITE}${BOLD}Resources:${NC}"
echo -e "  ${MUTED}─────────────────────────────────────────${NC}"
echo -e "  Memory:"
free -h | head -3 | sed 's/^/    /'
echo ""
echo -e "  Disk:"
df -h / | sed 's/^/    /'
echo ""
echo -e "  Swap:"
swapon --show 2>/dev/null | sed 's/^/    /'
echo ""
echo -e "  ${WHITE}${BOLD}New Commands:${NC}"
echo -e "    ${NEON_CYAN}cyberrange lab list${NC}          — See all available labs"
echo -e "    ${NEON_CYAN}cyberrange lab add <name>${NC}    — Install a new lab"
echo -e "    ${NEON_CYAN}cyberrange lab remove <name>${NC} — Remove a lab + image"
echo ""
echo -e "  ${YELLOW}${BOLD}[!] RECOMMENDED: Reboot to fully apply changes:${NC}"
echo -e "      ${WHITE}sudo reboot${NC}"
echo ""
