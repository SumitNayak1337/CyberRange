#!/usr/bin/env bash
# ==============================================================================
#   CYBERRANGE 2.0 // JUICE SHOP REMOVAL & 12GB RAM / 60GB DISK TUNING SCRIPT
#
#   Usage:
#       sudo bash remove-juiceshop.sh
#
#   What this script executes:
#     1. Completely stops and purges OWASP Juice Shop container & Docker image.
#     2. Reclaims 100% of the 60GB disk via LVM auto-expansion & Docker cleanup.
#     3. Allocates 12GB RAM optimally across DVWA, Splunk (4GB), Suricata (1GB),
#        and Shuffle SOAR (OpenSearch 1.5GB with 1GB JVM heap, Backend 1.5GB).
#     4. Removes all ASCII art font clutter from SSH login (clean, instant MOTD).
#     5. Fixes Suricata (/var/log/suricata) & OpenSearch (vm.max_map_count) for
#        flawless end-to-end SOC simulation (DVWA -> Suricata -> Splunk -> Shuffle).
#     6. Restarts all containers and launches the clean Web Dashboard on :9000.
# ==============================================================================

set -eo pipefail

# Colors
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

# Root check
if [[ $EUID -ne 0 ]]; then
    echo -e "${NEON_RED}[!] Error: Run with sudo/root: sudo bash remove-juiceshop.sh${NC}"
    exit 1
fi

# Clean up any partial or corrupt swapfile immediately to free disk space
if ! swapon --show | grep -q '/swapfile'; then
    rm -f /swapfile 2>/dev/null || true
fi

echo ""
echo -e "${NEON_CYAN}══════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}${BOLD}  CYBERRANGE 2.0 // JUICE SHOP REMOVAL & SIMULATION TUNER (12GB / 60GB)${NC}"
echo -e "${NEON_CYAN}══════════════════════════════════════════════════════════════════════════════${NC}"
echo ""

# ──────────────────────────────────────────────────────────────────
#  STEP 1: LOCATE LAB DIRECTORY
# ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR=""
if [[ -f "$SCRIPT_DIR/docker-compose.yml" ]]; then
    LAB_DIR="$SCRIPT_DIR"
elif [[ -f "/etc/cyberrange/lab_path" ]]; then
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
    echo -e "${NEON_RED}[!] Could not auto-detect Cyberrange_Programfiles directory.${NC}"
    read -rp "Enter full path to Cyberrange_Programfiles: " LAB_DIR
fi

echo -e "${NEON_AQUA}[*] Lab Directory:${NC} ${WHITE}$LAB_DIR${NC}"
mkdir -p /etc/cyberrange
echo "$LAB_DIR" > /etc/cyberrange/lab_path

COMPOSE_FILE="$LAB_DIR/docker-compose.yml"

# ──────────────────────────────────────────────────────────────────
#  STEP 2: STOP AND COMPLETELY PURGE OWASP JUICE SHOP
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GOLD}[1/6] Purging OWASP Juice Shop Container & Image...${NC}"

# Stop any running juice shop containers
docker stop cyberrange_juice cyberrange_juiceshop 2>/dev/null || true
docker rm -f cyberrange_juice cyberrange_juiceshop 2>/dev/null || true

# Find and remove any container with juice-shop ancestor
JUICE_CONTAINERS=$(docker ps -a --filter "ancestor=bkimminich/juice-shop" -q 2>/dev/null || true)
if [[ -n "$JUICE_CONTAINERS" ]]; then
    docker rm -f $JUICE_CONTAINERS 2>/dev/null || true
fi

# Remove Juice Shop docker image to free ~800MB disk space
docker rmi -f bkimminich/juice-shop:latest bkimminich/juice-shop 2>/dev/null || true

# Remove UFW port 3000 rule if present
if command -v ufw &>/dev/null; then
    ufw delete allow 3000/tcp 2>/dev/null || true
fi

echo -e "  ${BRIGHT_GREEN}[✓] OWASP Juice Shop completely removed from Docker and Firewall.${NC}"

# ──────────────────────────────────────────────────────────────────
#  STEP 3: RECLAIM 100% OF 60GB DISK & CONFIGURE STORAGE LIMITS
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GOLD}[2/6] Auto-Expanding Storage to 100% of 60GB Allocation...${NC}"

# 1. Resize Physical Volume (handles VMware disk expansion)
pvresize /dev/sda3 2>/dev/null || pvresize /dev/sda2 2>/dev/null || pvresize /dev/sda 2>/dev/null || pvresize /dev/nvme0n1p3 2>/dev/null || true

# 2. Expand Root LVM logical volume if used
ROOT_DEV=$(df / | tail -1 | awk '{print $1}')
if [[ "$ROOT_DEV" == *"/dev/mapper/"* || "$ROOT_DEV" == *"/dev/ubuntu-vg/"* ]]; then
    echo -e "  ${NEON_AQUA}[*] Extending LVM Volume: $ROOT_DEV to 100% free space...${NC}"
    lvextend -l +100%FREE "$ROOT_DEV" 2>/dev/null || true
    resize2fs "$ROOT_DEV" 2>/dev/null || xfs_growfs / 2>/dev/null || true
    echo -e "  ${BRIGHT_GREEN}[✓] Root partition extended to full capacity.${NC}"
else
    echo -e "  ${MUTED}[i] Standard partition: $ROOT_DEV${NC}"
fi

# 3. Docker Log Rotation Config (prevent container logs from ever filling 60GB disk)
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'DOCKER_CFG'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "50m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
DOCKER_CFG

# Truncate existing runaway Docker logs
sh -c 'truncate -s 0 /var/lib/docker/containers/*/*-json.log 2>/dev/null' || true

# Clean up dangling images and build cache
docker system prune -f 2>/dev/null || true
echo -e "  ${BRIGHT_GREEN}[✓] Docker log rotation (50MB x 3) & storage cleanup configured.${NC}"

# ──────────────────────────────────────────────────────────────────
#  STEP 4: ALLOCATE 12GB RAM ACROSS TOOLS & KERNEL SETTINGS
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GOLD}[3/6] Configuring 12GB RAM Allocations & System Kernel...${NC}"

# Set required virtual memory for OpenSearch (Shuffle Database)
sysctl -w vm.max_map_count=262144 2>/dev/null || true
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-cyberrange.conf << 'SYSCTL_EOF'
# CyberRange 2.0 Kernel Parameters for 12GB RAM
vm.max_map_count = 262144
vm.swappiness = 10
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
net.core.somaxconn = 2048
net.ipv4.tcp_tw_reuse = 1
SYSCTL_EOF
sysctl -p /etc/sysctl.d/99-cyberrange.conf 2>/dev/null || true

# Setup swap space safely (only if not active and enough disk space)
FREE_MB=$(df -m / | awk 'NR==2 {print $4}')
if swapon --show | grep -q '/swapfile'; then
    echo -e "  ${BRIGHT_GREEN}[✓] Swap file already active.${NC}"
elif [[ "$FREE_MB" -gt 6000 ]]; then
    echo -e "  ${NEON_AQUA}[*] Creating 2GB swap file for extra safety...${NC}"
    fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none 2>/dev/null || true
    chmod 600 /swapfile 2>/dev/null || true
    mkswap /swapfile >/dev/null 2>&1 || true
    swapon /swapfile 2>/dev/null || true
    if ! grep -q '/swapfile' /etc/fstab 2>/dev/null; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    echo -e "  ${BRIGHT_GREEN}[✓] Swap configured and active.${NC}"
else
    echo -e "  ${MUTED}[i] 12GB RAM present, skipping swap creation to preserve disk.${NC}"
fi

# Ensure Suricata logging directory has full permissions for live alert ingestion
mkdir -p /var/log/suricata
chmod -R 777 /var/log/suricata
touch /var/log/suricata/eve.json /var/log/suricata/fast.log
chmod 666 /var/log/suricata/eve.json /var/log/suricata/fast.log

# ──────────────────────────────────────────────────────────────────
#  STEP 5: WRITE OPTIMIZED DOCKER-COMPOSE.YML (NO JUICE SHOP)
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GOLD}[4/6] Updating docker-compose.yml with 12GB Allocations...${NC}"

cp "$COMPOSE_FILE" "${COMPOSE_FILE}.bak.$(date +%s)" 2>/dev/null || true

cat > "$COMPOSE_FILE" << 'COMPOSE_EOF'
services:

  # ──────────────────────────────────────────────────────────────
  #  RED TEAM TARGET — Damn Vulnerable Web Application
  # ──────────────────────────────────────────────────────────────
  dvwa:
    image: vulnerables/web-dvwa
    container_name: cyberrange_dvwa
    ports:
      - "8081:80"
    restart: unless-stopped
    mem_limit: 512m

  # ──────────────────────────────────────────────────────────────
  #  BLUE TEAM SIEM — Splunk Enterprise (Core Log Correlation)
  # ──────────────────────────────────────────────────────────────
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
      - "8000:8000"   # Splunk Web UI
      - "8088:8088"   # Splunk HEC
    volumes:
      - /var/log:/host_var_log:ro
      - splunk_data:/opt/splunk/var
    restart: unless-stopped
    mem_limit: 4g

  # ──────────────────────────────────────────────────────────────
  #  BLUE TEAM NIDS — Suricata (Live Host Packet Sniffer)
  # ──────────────────────────────────────────────────────────────
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
    mem_limit: 1g

  # ──────────────────────────────────────────────────────────────
  #  SHUFFLE SOAR — Security Orchestration, Automation & Response
  # ──────────────────────────────────────────────────────────────
  shuffle-frontend:
    image: ghcr.io/shuffle/shuffle-frontend:latest
    container_name: cyberrange_shuffle_frontend
    hostname: shuffle-frontend
    ports:
      - "3443:80"       # Shuffle Web UI
      - "3444:443"
    environment:
      - BACKEND_HOSTNAME=shuffle-backend
    restart: unless-stopped
    mem_limit: 512m
    depends_on:
      - shuffle-backend

  shuffle-backend:
    image: ghcr.io/shuffle/shuffle-backend:latest
    container_name: cyberrange_shuffle_backend
    hostname: shuffle-backend
    ports:
      - "5001:5001"     # Shuffle API
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
    mem_limit: 1536m
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
      - "OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g"
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
    mem_limit: 1536m

volumes:
  splunk_data:
  shuffle_apps:
  shuffle_files:
  shuffle_db_data:
COMPOSE_EOF

echo -e "  ${BRIGHT_GREEN}[✓] docker-compose.yml updated:${NC}"
echo -e "      • Splunk SIEM   : 4 GB RAM"
echo -e "      • Suricata NIDS : 1 GB RAM"
echo -e "      • Shuffle DB    : 1.5 GB RAM (1GB JVM Heap)"
echo -e "      • Shuffle API   : 1.5 GB RAM"
echo -e "      • DVWA Target   : 512 MB RAM"

# ──────────────────────────────────────────────────────────────────
#  STEP 6: REMOVE ASCII ART & CONFIGURE CLEAN SSH TERMINAL MOTD
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GOLD}[5/6] Removing ASCII Art & Installing Fast, Clean SSH Banner...${NC}"

# Mute noisy Ubuntu MOTD advertisements & help text
if [[ -d "/etc/update-motd.d" ]]; then
    chmod -x /etc/update-motd.d/10-help-text 2>/dev/null || true
    chmod -x /etc/update-motd.d/50-motd-news 2>/dev/null || true
    chmod -x /etc/update-motd.d/88-esm-announce 2>/dev/null || true
    chmod -x /etc/update-motd.d/91-release-upgrade 2>/dev/null || true
    chmod -x /etc/update-motd.d/95-hwe-eol 2>/dev/null || true
fi

# Write clean banner script
cat > "$LAB_DIR/banner.sh" << 'BANNER_EOF'
#!/usr/bin/env bash
NC='\033[0m'; BOLD='\033[1m'; CYAN='\033[0;36m'; NEON_CYAN='\033[38;5;51m'
NEON_AQUA='\033[38;5;49m'; BRIGHT_GREEN='\033[38;5;46m'; GOLD='\033[38;5;220m'
NEON_RED='\033[38;5;196m'; MAGENTA='\033[38;5;201m'; WHITE='\033[1;37m'; MUTED='\033[38;5;244m'

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
                ip="$cand"; break
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
BANNER_EOF

chmod +x "$LAB_DIR/banner.sh"

# Install into update-motd.d and profile.d
if [[ -d "/etc/update-motd.d" ]]; then
    cp "$LAB_DIR/banner.sh" /etc/update-motd.d/99-cyberrange 2>/dev/null || true
    chmod +x /etc/update-motd.d/99-cyberrange 2>/dev/null || true
fi

cat > /etc/profile.d/cyberrange-banner.sh << 'EOF_PROF'
# CyberRange clean MOTD
if [ -n "$PS1" ] && [ -x /usr/local/bin/cyberrange ]; then
    /usr/local/bin/cyberrange banner
fi
EOF_PROF
chmod +x /etc/profile.d/cyberrange-banner.sh

# Update CLI binary symlink
chmod +x "$LAB_DIR/cyberrange"
ln -sf "$LAB_DIR/cyberrange" /usr/local/bin/cyberrange
chmod +x /usr/local/bin/cyberrange

echo -e "  ${BRIGHT_GREEN}[✓] ASCII art removed. Clean, functional SSH login installed.${NC}"

# ──────────────────────────────────────────────────────────────────
#  STEP 7: RESTART LAB AND LAUNCH CLEAN DASHBOARD
# ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GOLD}[6/6] Launching Containers and Web Dashboard...${NC}"

# Clean port 9000
pkill -f "python3 -m http.server 9000" 2>/dev/null || true

# Start everything via main cyberrange CLI
if [[ -x "$LAB_DIR/cyberrange" ]]; then
    "$LAB_DIR/cyberrange" start
elif command -v cyberrange &>/dev/null; then
    cyberrange start
else
    (cd "$LAB_DIR" && docker compose up -d)
    mkdir -p "$LAB_DIR/dashboard"
    nohup python3 -m http.server 9000 --directory "$LAB_DIR/dashboard" >/dev/null 2>&1 &
fi

echo ""
echo -e "${NEON_GREEN}══════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}${BOLD}  [✓] CYBERRANGE 2.0 SOC ENVIRONMENT IS READY!${NC}"
echo -e "${NEON_GREEN}══════════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${WHITE}${BOLD}System Resources Active:${NC}"
free -h | awk 'NR<=2 {print "    " $0}'
echo ""
df -h / | awk 'NR<=2 {print "    " $0}'
echo ""
"$LAB_DIR/banner.sh"

