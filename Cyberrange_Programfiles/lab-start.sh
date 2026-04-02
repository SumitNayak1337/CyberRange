#!/bin/bash

# ============================================================
#   CyberRange SOC Lab Launcher â€” Aesthetic GitHub Edition
# ============================================================

# Define color codes
GRN='\033[0;32m'
CYN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GRN}[*] SOC Lab initialization sequence started...${NC}"

# --- Prerequisites Check ---

if ! [ -x "$(command -v docker compose)" ]; then
  if ! [ -x "$(command -v docker-compose)" ]; then
    echo -e "${RED}[!] Error: docker-compose is not installed.${NC}"
    exit 1
  fi
  DOCKER_CMD="docker-compose"
else
  DOCKER_CMD="docker compose"
fi

if ! [[ -f "docker-compose.yml" ]]; then
    echo -e "${RED}[!] Error: docker-compose.yml not found in current directory.${NC}"
    exit 1
fi


# --- 1. Smart LAN IP Detection (Bulletproof) ---
echo -e "${GRN}[*] Detecting LAN IP...${NC}"

# Method 1: Check for ens33 interface (user specified)
if [[ -n "$(ip link show ens33 2>/dev/null)" ]]; then
    LAN_IP=$(ip -4 addr show ens33 | awk '/inet / {print $2}' | cut -d/ -f1)
    if [[ -n "$LAN_IP" && ! "$LAN_IP" =~ ^169\.254 ]]; then
        echo -e "${GRN}[âœ“] Detected IP from ens33: $LAN_IP${NC}"
    fi
fi

# Method 2: Windows-friendly method: Get IP from ipconfig (if ens33 not found or failed)
if [[ -z "$LAN_IP" || "$LAN_IP" =~ ^169\.254 ]]; then
    LAN_IP=$(ipconfig | findstr IPv4 | head -1 | awk '{print $NF}' | tr -d '\r')
fi

# Method 3: Fallback method: If ipconfig fails, try getting from default gateway
if [[ -z "$LAN_IP" || "$LAN_IP" =~ ^169\.254 ]]; then
    LAN_IP=$(ipconfig | findstr "Default Gateway" | head -1 | awk '{print $NF}' | tr -d '\r')
    # If gateway is found, use a common IP in that subnet
    if [[ -n "$LAN_IP" && ! "$LAN_IP" =~ ^169\.254 ]]; then
        LAN_IP=$(echo "$LAN_IP" | awk -F'.' '{print $1"."$2"."$3".100"}')
    fi
fi

# Emergency Failsafe: localhost
if [[ -z "$LAN_IP" || "$LAN_IP" =~ ^169\.254 ]]; then
    LAN_IP="127.0.0.1"
    echo -e "${RED}[!] Warning: No network IP detected. Using localhost.${NC}"
else
    echo -e "${GRN}[âœ“] Detected IP: $LAN_IP${NC}"
fi


# --- 2. Setup dirs ---
DASHBOARD_DIR="./dashboard"
rm -rf "$DASHBOARD_DIR" 2>/dev/null
mkdir -p "$DASHBOARD_DIR"


# --- 3. Generate Aesthetic Dashboard (Dynamic IP) ---
echo -e "${GRN}[*] Building aesthetic dashboard...${NC}"

cat << HTMLEOF > "$DASHBOARD_DIR/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>CyberRange // SOC Lab Dashboard</title>
    <link href="https://fonts.googleapis.com/css2?family=Share+Tech+Mono&family=Orbitron:wght@700;900&display=swap" rel="stylesheet">
    <style>
        :root{--bg:#060a0f;--surface:#0b1117;--border:#1a2a1a;--green:#00ff88;--cyan:#00e5ff;--text:#c8d8c8;--muted:#4a6a4a;--head:'Orbitron',monospace;--mono:'Share Tech Mono',monospace;}
        *,*::before,*::after{box-sizing:border-box;margin:0;padding:0;}
        body{background:var(--bg);color:var(--text);font-family:var(--mono);min-height:100vh;overflow-x:hidden;}
        body::before{content:'';position:fixed;inset:0;background:repeating-linear-gradient(0deg,transparent,transparent 2px,rgba(0,255,136,.015) 2px,rgba(0,255,136,.015) 4px);pointer-events:none;z-index:100;}
        .wrap{position:relative;z-index:1;max-width:960px;margin:0 auto;padding:40px 20px 60px;}
        header{text-align:center;margin-bottom:48px;}
        .logo{font-family:var(--head);font-size:3rem;font-weight:900;letter-spacing:.1em;color:var(--green);text-shadow:0 0 20px rgba(0,255,136,.6);animation:glow 3s ease-in-out infinite;}
        .logo span{color:var(--cyan);}
        @keyframes glow{0%,100%{text-shadow:0 0 20px rgba(0,255,136,.6);}50%{text-shadow:0 0 30px rgba(0,255,136,.9);}}
        .tagline{margin-top:8px;font-size:.8rem;color:var(--muted);letter-spacing:.3em;text-transform:uppercase;}
        .sbar{display:flex;align-items:center;justify-content:space-between;background:var(--surface);border:1px solid var(--border);border-left:3px solid var(--green);padding:12px 20px;margin-bottom:36px;font-size:.78rem;flex-wrap:wrap;}
        .ipbadge{font-family:var(--head);font-size:.7rem;color:var(--cyan);background:rgba(0,229,255,.07);border:1px solid rgba(0,229,255,.2);padding:4px 10px;letter-spacing:.1em;}
        .slabel{font-size:.65rem;letter-spacing:.4em;color:var(--muted);text-transform:uppercase;margin-bottom:14px;}
        .cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px;}
        .card{background:var(--surface);border:1px solid var(--border);padding:24px;position:relative;overflow:hidden;transition:all .2s;text-decoration:none;display:block;}
        .card::before{content:'';position:absolute;top:0;left:0;width:100%;height:2px;background:var(--ac,var(--green));box-shadow:0 0 12px var(--ac,var(--green));}
        .card:hover{border-color:var(--ac,var(--green));transform:translateY(-2px);}
        .cb{color:var(--ac,var(--green));font-family:var(--head);font-size:.6rem;letter-spacing:.2em;padding:3px 8px;border:1px solid var(--ac,var(--green));text-transform:uppercase;display:inline-block;margin-bottom:12px;}
        .ct{font-family:var(--head);font-size:1.1rem;font-weight:700;color:#fff;margin-bottom:6px;}
        .cd{font-size:.75rem;color:var(--muted);line-height:1.6;margin-bottom:16px;}
        .cc{background:rgba(0,0,0,.4);border:1px solid rgba(255,255,255,.05);padding:8px 12px;font-size:.7rem;line-height:1.8;}
        .cl{color:var(--muted);margin-right:6px;}.cv{color:var(--green);}
        .dvwa{--ac:#ff4455;} .juice{--ac:#ffcc00;} .splunk{--ac:#00e5ff;}
        footer{margin-top:48px;text-align:center;font-size:.65rem;color:var(--muted);letter-spacing:.2em;}
    </style>
</head>
<body>
<div class="wrap">
    <header>
        <div class="logo">CYBER<span>RANGE</span></div>
        <div class="tagline">// SOC Lab Environment</div>
    </header>
    <div class="sbar">
        <div>â— SYSTEM ONLINE | Active Services Dashboard</div>
        <div class="ipbadge">ðŸ–§ HOST IP: $LAN_IP</div>
    </div>
    <div class="slabel">â–¶ Attack Targets (Red Team)</div>
    <div class="cards" style="margin-bottom:32px;">
        <a class="card dvwa" href="http://$LAN_IP:8081" target="_blank">
            <span class="cb">VULNERABLE</span>
            <div class="ct">DVWA</div>
            <div class="cd">Damn Vulnerable Web App. Standard challenges: SQLi, XSS, Command Injection.</div>
            <div class="cc"><div><span class="cl">USER</span><span class="cv">admin</span></div><div><span class="cl">PASS</span><span class="cv">password</span></div></div>
        </a>
        <a class="card juice" href="http://$LAN_IP:3000" target="_blank">
            <span class="cb">VULNERABLE</span>
            <div class="ct">OWASP Juice Shop</div>
            <div class="cd">Advanced Node.js/Angular challenges. Intentionally insecure ecommerce app.</div>
            <div class="cc"><div><span class="cl">NOTE</span><span class="cv">Register inside app</span></div></div>
        </a>
    </div>
    <div class="slabel">â–¶ Defense & Monitoring (Blue Team)</div>
    <div class="cards">
        <a class="card splunk" href="http://$LAN_IP:8000" target="_blank">
            <span class="cb">SIEM</span>
            <div class="ct">Splunk Enterprise</div>
            <div class="cd">Core logging and analysis platform. Monitor attacks against DVWA/Juice Shop.</div>
            <div class="cc"><div><span class="cl">USER</span><span class="cv">admin</span></div><div><span class="cl">PASS</span><span class="cv">CyberRange@123</span></div></div>
        </a>
    </div>
    <footer>CYBERRANGE &nbsp;Â·&nbsp; EDUCATIONAL USE ONLY &nbsp;Â·&nbsp; ISOLATED LAB ENVIRONMENT</footer>
</div>
</body>
</html>
HTMLEOF


# --- 4. Start Lab Services (Crucial Fix) ---
echo -e "${GRN}[*] Launching Docker containers via $DOCKER_CMD...${NC}"
# Pre-clean just in case a previous run failed.
$DOCKER_CMD down > /dev/null 2>&1
$DOCKER_CMD up -d


# --- 5. Start Dashboard Web Server ---
echo -e "${GRN}[*] Launching Aesthetic Dashboard on Port 9000...${NC}"
# Kill existing server if running (Windows-compatible)
taskkill /f /im python.exe 2>/dev/null || true
sleep 1
# Serve ONLY from the generated dashboard directory
python3 -m http.server 9000 --directory "$DASHBOARD_DIR" > /dev/null 2>&1 &

echo -e "\nâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€"
echo -e "${CYN}[+] SUCCESS: CyberRange SOC Lab is LIVE!${NC}"
echo -e "â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€"
echo -e "  Main Dashboard  â†’ http://${LAN_IP}:9000"
echo -e "â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€"
echo -e "  DVWA            â†’ http://${LAN_IP}:8081"
echo -e "  Juice Shop      â†’ http://${LAN_IP}:3000"
echo -e "  Splunk SIEM     â†’ http://${LAN_IP}:8000"
echo -e "â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€\n"