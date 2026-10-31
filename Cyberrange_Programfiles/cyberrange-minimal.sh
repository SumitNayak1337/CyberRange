#!/usr/bin/env bash
# ==============================================================================
#   CYBERRANGE 2.0 // MINIMAL SOC LAB SETUP
#   One script to rule them all. SCP it, SSH run it, done.
#
#   Keeps ONLY: DVWA + Splunk + Suricata + Shuffle SOAR
#   Removes: Juice Shop, ASCII art spam, GUI bloat, unnecessary services
#
#   Usage:
#       scp cyberrange-minimal.sh cyberrange@<IP>:~/
#       ssh -t cyberrange@<IP> "sudo bash ~/cyberrange-minimal.sh"
# ==============================================================================

set -eo pipefail

NC='\033[0m'; BOLD='\033[1m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'

# ─── ROOT CHECK ──────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[!] Run as root: sudo bash cyberrange-minimal.sh${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}${BOLD}  CYBERRANGE 2.0 // MINIMAL SOC LAB SETUP${NC}"
echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════${NC}"
echo ""

# ─── DETECT LAB DIRECTORY ────────────────────────────────────────
LAB_DIR=""
for d in "/home/cyberrange/CyberRange/Cyberrange_Programfiles" \
         "/home/cyberrange/Cyberrange_Programfiles" \
         "/opt/cyberrange/Cyberrange_Programfiles" \
         "/root/CyberRange/Cyberrange_Programfiles"; do
    if [[ -d "$d" ]]; then
        LAB_DIR="$d"
        break
    fi
done

# Try from /etc/cyberrange/lab_path
if [[ -z "$LAB_DIR" && -f "/etc/cyberrange/lab_path" ]]; then
    LAB_DIR="$(cat /etc/cyberrange/lab_path)"
fi

# Search for docker-compose.yml
if [[ -z "$LAB_DIR" || ! -d "$LAB_DIR" ]]; then
    FOUND=$(find /home -maxdepth 5 -name "docker-compose.yml" -path "*/Cyberrange*" 2>/dev/null | head -1)
    if [[ -n "$FOUND" ]]; then
        LAB_DIR="$(dirname "$FOUND")"
    fi
fi

if [[ -z "$LAB_DIR" || ! -d "$LAB_DIR" ]]; then
    echo -e "${RED}[!] Cannot find CyberRange lab directory.${NC}"
    echo -e "${YELLOW}Enter full path to Cyberrange_Programfiles:${NC}"
    read -r LAB_DIR
fi

if [[ ! -d "$LAB_DIR" ]]; then
    echo -e "${RED}[!] Directory not found: $LAB_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}[✓] Lab directory: ${WHITE}$LAB_DIR${NC}"
mkdir -p /etc/cyberrange
echo "$LAB_DIR" > /etc/cyberrange/lab_path

# ─── DETECT IP ───────────────────────────────────────────────────
detect_ip() {
    local ip=""
    ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || true)
    [[ -z "$ip" ]] && ip=$(ip -4 addr show ens33 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1 || true)
    [[ -z "$ip" ]] && ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
    [[ -z "$ip" ]] && ip="127.0.0.1"
    echo "$ip"
}
HOST_IP=$(detect_ip)

# ══════════════════════════════════════════════════════════════════
#  STEP 1: STOP EVERYTHING & KILL JUICE SHOP
# ══════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}[1/7] Stopping all services & purging Juice Shop...${NC}"

pkill -f "python3 -m http.server 9000" 2>/dev/null || true

cd "$LAB_DIR"
docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true

# Kill Juice Shop completely
docker stop cyberrange_juice cyberrange_juiceshop 2>/dev/null || true
docker rm -f cyberrange_juice cyberrange_juiceshop 2>/dev/null || true
for img in $(docker images -q bkimminich/juice-shop 2>/dev/null); do
    docker rmi -f "$img" 2>/dev/null || true
done

# Remove broken swap file if exists
swapoff /swapfile 2>/dev/null || true
rm -f /swapfile 2>/dev/null || true
sed -i '/\/swapfile/d' /etc/fstab 2>/dev/null || true

echo -e "${GREEN}  [✓] Services stopped. Juice Shop purged.${NC}"

# ══════════════════════════════════════════════════════════════════
#  STEP 2: EXPAND DISK TO FULL CAPACITY
# ══════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}[2/7] Expanding disk to full capacity...${NC}"

# Install growpart if missing
apt-get update -qq 2>/dev/null || true
apt-get install -y -qq cloud-guest-utils 2>/dev/null || true

# Find the LVM partition (usually sda3 on Ubuntu Server)
DISK_DEV=""
PART_NUM=""
for part in /dev/sda3 /dev/sda2 /dev/nvme0n1p3 /dev/nvme0n1p2; do
    if [[ -b "$part" ]] && pvs "$part" 2>/dev/null | grep -q "$part"; then
        DISK_DEV=$(echo "$part" | sed 's/[0-9]*$//' | sed 's/p$//')
        PART_NUM=$(echo "$part" | grep -oP '[0-9]+$')
        break
    fi
done

if [[ -n "$DISK_DEV" && -n "$PART_NUM" ]]; then
    echo -e "  [*] Growing partition ${DISK_DEV}${PART_NUM}..."
    growpart "$DISK_DEV" "$PART_NUM" 2>/dev/null || true
    pvresize "${DISK_DEV}${PART_NUM}" 2>/dev/null || pvresize "${DISK_DEV}p${PART_NUM}" 2>/dev/null || true
fi

ROOT_DEV=$(df / | tail -1 | awk '{print $1}')
if [[ "$ROOT_DEV" == *"/dev/mapper/"* ]]; then
    lvextend -l +100%FREE "$ROOT_DEV" 2>/dev/null || true
    resize2fs "$ROOT_DEV" 2>/dev/null || xfs_growfs / 2>/dev/null || true
fi

# Clean Docker dangling garbage without removing base images
sh -c 'truncate -s 0 /var/lib/docker/containers/*/*-json.log 2>/dev/null' || true
docker container prune -f 2>/dev/null || true
docker image prune -f 2>/dev/null || true

DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
echo -e "${GREEN}  [✓] Disk expanded. Free space: ${WHITE}$DISK_FREE${NC}"

# ══════════════════════════════════════════════════════════════════
#  STEP 3: KERNEL & SYSTEM TUNING
# ══════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}[3/7] Configuring kernel & system settings...${NC}"

# OpenSearch needs this
sysctl -w vm.max_map_count=262144 2>/dev/null || true
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-cyberrange.conf << 'EOF'
vm.max_map_count = 262144
vm.swappiness = 10
EOF
sysctl -p /etc/sysctl.d/99-cyberrange.conf 2>/dev/null || true

# Docker log rotation
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": { "max-size": "20m", "max-file": "2" },
    "storage-driver": "overlay2"
}
EOF
systemctl restart docker
sleep 2

# Suricata log dir
mkdir -p /var/log/suricata
chmod -R 777 /var/log/suricata

# Firewall
if command -v ufw &>/dev/null; then
    ufw delete allow 3000/tcp 2>/dev/null || true
    for port in 22 8000 8081 8088 3443 5001 9000; do
        ufw allow "$port"/tcp 2>/dev/null || true
    done
fi

echo -e "${GREEN}  [✓] System configured.${NC}"

# ══════════════════════════════════════════════════════════════════
#  STEP 4: WRITE MINIMAL DOCKER-COMPOSE (4 TOOLS ONLY)
# ══════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}[4/7] Writing minimal docker-compose.yml...${NC}"

# Detect RAM and allocate smartly
TOTAL_RAM_MB=$(free -m | awk '/Mem:/ {print $2}')
if [[ "$TOTAL_RAM_MB" -ge 12000 ]]; then
    SPLUNK_MEM="4g"; SURICATA_MEM="1g"; SHUF_BACK="1536m"; SHUF_DB="1536m"
    SHUF_DB_HEAP="-Xms1g -Xmx1g"; DVWA_MEM="512m"; SHUF_FRONT="512m"; SHUF_ORB="512m"
elif [[ "$TOTAL_RAM_MB" -ge 8000 ]]; then
    SPLUNK_MEM="2g"; SURICATA_MEM="512m"; SHUF_BACK="1g"; SHUF_DB="1g"
    SHUF_DB_HEAP="-Xms512m -Xmx512m"; DVWA_MEM="256m"; SHUF_FRONT="256m"; SHUF_ORB="256m"
else
    SPLUNK_MEM="1g"; SURICATA_MEM="256m"; SHUF_BACK="512m"; SHUF_DB="768m"
    SHUF_DB_HEAP="-Xms256m -Xmx256m"; DVWA_MEM="128m"; SHUF_FRONT="128m"; SHUF_ORB="256m"
fi

cp "$LAB_DIR/docker-compose.yml" "$LAB_DIR/docker-compose.yml.bak.$(date +%s)" 2>/dev/null || true

cat > "$LAB_DIR/docker-compose.yml" << COMPOSE_EOF
services:

  dvwa:
    image: vulnerables/web-dvwa
    container_name: cyberrange_dvwa
    ports:
      - "8081:80"
    restart: unless-stopped
    mem_limit: ${DVWA_MEM}

  splunk:
    image: splunk/splunk:latest
    container_name: cyberrange_splunk
    environment:
      - SPLUNK_START_ARGS=--accept-license
      - SPLUNK_PASSWORD=CyberRange@123
      - SPLUNK_GENERAL_TERMS=--accept-sgt-current-at-splunk-com
      - SPLUNK_HEC_TOKEN=12345678-1234-1234-1234-1234567890ab
    ports:
      - "8000:8000"
      - "8088:8088"
    volumes:
      - /var/log:/host_var_log:ro
      - splunk_data:/opt/splunk/var
    restart: unless-stopped
    mem_limit: ${SPLUNK_MEM}

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
    mem_limit: ${SURICATA_MEM}

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
    mem_limit: ${SHUF_FRONT}
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
    mem_limit: ${SHUF_BACK}
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
    mem_limit: ${SHUF_ORB}
    depends_on:
      - shuffle-backend

  shuffle-database:
    image: opensearchproject/opensearch:2.14.0
    container_name: cyberrange_shuffle_db
    hostname: shuffle-database
    environment:
      - "OPENSEARCH_JAVA_OPTS=${SHUF_DB_HEAP}"
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
    mem_limit: ${SHUF_DB}

volumes:
  splunk_data:
  shuffle_apps:
  shuffle_files:
  shuffle_db_data:
COMPOSE_EOF

echo -e "${GREEN}  [✓] docker-compose.yml written (Splunk=${SPLUNK_MEM}, Suricata=${SURICATA_MEM}).${NC}"

# ══════════════════════════════════════════════════════════════════
#  STEP 5: WRITE CLEAN BANNER (NO ASCII ART)
# ══════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}[5/7] Installing clean SSH login banner...${NC}"

cat > "$LAB_DIR/banner.sh" << 'BANNER_SCRIPT'
#!/usr/bin/env bash
NC='\033[0m'; BOLD='\033[1m'; CYAN='\033[38;5;51m'; GREEN='\033[38;5;46m'
GOLD='\033[38;5;220m'; RED='\033[38;5;196m'; MAG='\033[38;5;201m'
WHITE='\033[1;37m'; MUTED='\033[38;5;244m'; AQUA='\033[38;5;49m'
IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}${BOLD}  CYBERRANGE 2.0 // SOC LAB${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "  ${WHITE}HOST :${NC} ${GOLD}${BOLD}${IP}${NC}    ${WHITE}DASHBOARD :${NC} ${AQUA}http://${IP}:9000${NC}"
echo -e "${MUTED}  ─────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${RED}${BOLD}RED${NC}  DVWA         ${AQUA}http://${IP}:8081${NC}  ${MUTED}admin / password${NC}"
echo -e "  ${CYAN}${BOLD}BLUE${NC} Splunk SIEM  ${AQUA}http://${IP}:8000${NC}  ${MUTED}admin / CyberRange@123${NC}"
echo -e "       Splunk HEC  ${AQUA}http://${IP}:8088${NC}"
echo -e "       Suricata    ${GREEN}ACTIVE${NC} ${MUTED}/var/log/suricata/eve.json${NC}"
echo -e "  ${MAG}${BOLD}SOAR${NC} Shuffle     ${AQUA}http://${IP}:3443${NC}  ${MUTED}admin / CyberRange@123${NC}"
echo -e "       Shuffle API ${AQUA}http://${IP}:5001${NC}"
echo -e "${MUTED}  ─────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${MUTED}cyberrange start | stop | status | fix | restart${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
BANNER_SCRIPT
chmod +x "$LAB_DIR/banner.sh"

# Silence Ubuntu MOTD noise
if [[ -d /etc/update-motd.d ]]; then
    for f in /etc/update-motd.d/[0-9]*; do
        [[ "$(basename "$f")" != "99-cyberrange" ]] && chmod -x "$f" 2>/dev/null || true
    done
    cp "$LAB_DIR/banner.sh" /etc/update-motd.d/99-cyberrange
    chmod +x /etc/update-motd.d/99-cyberrange
fi

# Profile.d hook
cat > /etc/profile.d/cyberrange-banner.sh << 'EOF'
if [ -n "$PS1" ] && [ -x /usr/local/bin/cyberrange ]; then
    /usr/local/bin/cyberrange banner 2>/dev/null
fi
EOF
chmod +x /etc/profile.d/cyberrange-banner.sh

echo -e "${GREEN}  [✓] Clean banner installed.${NC}"

# ══════════════════════════════════════════════════════════════════
#  STEP 6: WRITE MINIMAL WEB DASHBOARD
# ══════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}[6/7] Generating web dashboard...${NC}"

DASH_DIR="$LAB_DIR/dashboard"
mkdir -p "$DASH_DIR"

cat > "$DASH_DIR/index.html" << DASHEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>CyberRange 2.0 SOC Lab</title>
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{background:#0a0e17;color:#e0e0e0;font-family:'Segoe UI',sans-serif;min-height:100vh;display:flex;flex-direction:column;align-items:center;padding:20px}
  h1{color:#00e5ff;font-size:1.8rem;margin:20px 0 5px}
  .sub{color:#888;font-size:.85rem;margin-bottom:30px}
  .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px;max-width:1000px;width:100%}
  .card{background:rgba(15,22,35,.9);border:1px solid rgba(255,255,255,.08);border-radius:12px;padding:20px;border-left:3px solid var(--c)}
  .card h3{color:var(--c);font-size:1.1rem;margin-bottom:6px}
  .card p{color:#999;font-size:.82rem;margin-bottom:12px}
  .cred{font-size:.78rem;color:#777;margin-bottom:12px}
  .cred b{color:#ccc}
  a.btn{display:inline-block;background:var(--c);color:#000;padding:8px 16px;border-radius:6px;text-decoration:none;font-weight:600;font-size:.85rem}
  a.btn:hover{opacity:.85}
  .section{color:#888;font-size:.75rem;text-transform:uppercase;letter-spacing:2px;margin:25px 0 10px;max-width:1000px;width:100%}
</style>
</head>
<body>
<h1>🛡️ CyberRange 2.0</h1>
<p class="sub">Security Operations Center Lab — ${HOST_IP}</p>

<div class="section">🔴 Red Team Target</div>
<div class="grid">
  <div class="card" style="--c:#ff3366">
    <h3>DVWA</h3>
    <p>SQL Injection, XSS, CSRF, Command Injection, File Inclusion</p>
    <div class="cred"><b>admin</b> / <b>password</b></div>
    <a class="btn" href="http://${HOST_IP}:8081" target="_blank">Launch DVWA ↗</a>
  </div>
</div>

<div class="section">🔵 Blue Team — SIEM & Detection</div>
<div class="grid">
  <div class="card" style="--c:#00e5ff">
    <h3>Splunk Enterprise</h3>
    <p>SIEM — Log aggregation, correlation rules, alert dashboards</p>
    <div class="cred"><b>admin</b> / <b>CyberRange@123</b> · HEC on :8088</div>
    <a class="btn" href="http://${HOST_IP}:8000" target="_blank">Open Splunk ↗</a>
  </div>
  <div class="card" style="--c:#00ff88">
    <h3>Suricata NIDS</h3>
    <p>Network IDS — Live packet inspection on host interface</p>
    <div class="cred">Logs: <b>/var/log/suricata/eve.json</b></div>
    <a class="btn" href="#" onclick="navigator.clipboard.writeText('tail -f /var/log/suricata/eve.json');this.textContent='Copied!';setTimeout(()=>this.textContent='Copy Tail Command',1500)">Copy Tail Command</a>
  </div>
</div>

<div class="section">⚡ SOAR — Automated Response</div>
<div class="grid">
  <div class="card" style="--c:#bd00ff">
    <h3>Shuffle SOAR</h3>
    <p>Playbook automation — auto-block, ticketing, IOC enrichment</p>
    <div class="cred"><b>admin</b> / <b>CyberRange@123</b> · API Key: <b>cyberrange-shuffle-api-key-2024</b></div>
    <a class="btn" href="http://${HOST_IP}:3443" target="_blank">Open Shuffle ↗</a>
  </div>
</div>

</body>
</html>
DASHEOF

echo -e "${GREEN}  [✓] Dashboard generated at ${DASH_DIR}/index.html${NC}"

# ══════════════════════════════════════════════════════════════════
#  STEP 7: START EVERYTHING
# ══════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}[7/7] Starting containers & web dashboard...${NC}"

# Ensure cyberrange CLI is linked
if [[ -f "$LAB_DIR/cyberrange" ]]; then
    chmod +x "$LAB_DIR/cyberrange"
    ln -sf "$LAB_DIR/cyberrange" /usr/local/bin/cyberrange
fi

# Start containers
cd "$LAB_DIR"
docker compose up -d || docker-compose up -d || true

# Start dashboard web server
pkill -f "python3 -m http.server 9000" 2>/dev/null || true
sleep 1
nohup python3 -m http.server 9000 --directory "$DASH_DIR" >/dev/null 2>&1 &

# Wait a moment for containers to initialize
sleep 3

# ══════════════════════════════════════════════════════════════════
#  DONE — SHOW STATUS
# ══════════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}${BOLD}  [✓] CYBERRANGE MINIMAL SOC LAB IS LIVE!${NC}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
echo ""

# Show container status
echo -e "  ${WHITE}CONTAINERS:${NC}"
for c in cyberrange_dvwa cyberrange_splunk cyberrange_suricata \
         cyberrange_shuffle_frontend cyberrange_shuffle_backend \
         cyberrange_shuffle_orborus cyberrange_shuffle_db; do
    st=$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null || echo "not found")
    if [[ "$st" == "running" ]]; then
        echo -e "    ${GREEN}[✓]${NC} $c"
    else
        echo -e "    ${YELLOW}[~]${NC} $c ($st — starting up...)"
    fi
done

echo ""
echo -e "  ${WHITE}RESOURCES:${NC}"
free -h | awk '/Mem:/ {printf "    RAM:  %s / %s\n", $3, $2}'
df -h / | awk 'NR==2 {printf "    DISK: %s / %s (%s used)\n", $3, $2, $5}'

echo ""
echo -e "  ${WHITE}ACCESS:${NC}"
echo -e "    Dashboard  → ${CYAN}http://${HOST_IP}:9000${NC}"
echo -e "    DVWA       → ${CYAN}http://${HOST_IP}:8081${NC}  (admin / password)"
echo -e "    Splunk     → ${CYAN}http://${HOST_IP}:8000${NC}  (admin / CyberRange@123)"
echo -e "    Shuffle    → ${CYAN}http://${HOST_IP}:3443${NC}  (admin / CyberRange@123)"
echo -e "    Suricata   → /var/log/suricata/eve.json"
echo ""
echo -e "  ${YELLOW}Note: Splunk takes 2-3 mins to fully boot. Shuffle may take 1-2 mins.${NC}"
echo ""

