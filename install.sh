#!/bin/bash

# ============================================================
# Climind v5 — Smart Installer / Updater / Remover
# https://github.com/Erfan-8910/Climind-W
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

INSTALL_DIR="${CLIMIND_DIR:-$HOME/climind}"
PORT=8080
GITHUB_RAW="https://raw.githubusercontent.com/Erfan-8910/Climind-W/main/index.html"

clear

echo ""
echo -e "${CYAN}${BOLD}"
echo "    ███████╗██████╗ ███████╗ █████╗ ███╗   ██╗    ██████╗██╗     ██╗███╗   ███╗███╗   ██╗██████╗ "
echo "    ██╔════╝██╔══██╗██╔════╝██╔══██╗████╗  ██║   ██╔════╝██║     ██║████╗ ████║████╗  ██║██╔══██╗"
echo "    █████╗  ██████╔╝█████╗  ███████║██╔██╗ ██║   ██║     ██║     ██║██╔████╔██║██╔██╗ ██║██║  ██║"
echo "    ██╔══╝  ██╔══██╗██╔══╝  ██╔══██║██║╚██╗██║   ██║     ██║     ██║██║╚██╔╝██║██║╚██╗██║██║  ██║"
echo "    ███████╗██║  ██║██║     ██║  ██║██║ ╚████║   ╚██████╗███████╗██║██║ ╚═╝ ██║██║ ╚████║██████╔╝"
echo "    ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝    ╚═════╝╚══════╝╚═╝╚═╝     ╚═╝╚═╝  ╚═══╝╚═════╝ "
echo ""
echo -e "${MAGENTA}                              v5.0.0  —  Weather  ·  Focus  ·  Toolbox${NC}"
echo -e "${DIM}                         Install Dir: $INSTALL_DIR${NC}"
echo ""
echo -e "${YELLOW}─────────────────────────────────────────────────────────────────────────────────────────────────────${NC}"
echo ""

# ─── Detect runtime ───
SERVER=""
if command -v python3 &> /dev/null; then
    SERVER="python3"
    VERSION=$(python3 --version 2>&1 | awk '{print $2}')
elif command -v python &> /dev/null; then
    SERVER="python"
    VERSION=$(python --version 2>&1 | awk '{print $2}')
elif command -v node &> /dev/null; then
    SERVER="node"
    VERSION=$(node --version)
fi

if [ -z "$SERVER" ]; then
    echo -e "  ${RED}${BOLD}✖  No server runtime found.${NC}"
    echo -e "  ${BLUE}   ℹ  Install Python 3 or Node.js first.${NC}"
    echo ""
    exit 1
fi

# ─── Check if already installed ───
IS_INSTALLED=false
if [ -f "$INSTALL_DIR/index.html" ]; then
    IS_INSTALLED=true
    CURRENT_VER=$(cat "$INSTALL_DIR/.version" 2>/dev/null || echo "unknown")
fi

# ─── Menu ───
if [ "$IS_INSTALLED" = true ]; then
    echo -e "  ${GREEN}${BOLD}✓  Climind is already installed!${NC} ${DIM}(version: $CURRENT_VER)${NC}"
    echo ""
    echo -e "  ${CYAN}${BOLD}What would you like to do?${NC}"
    echo ""
    echo -e "     ${YELLOW}[S]${NC} ${BOLD}Start${NC}     — Launch the local server"
    echo -e "     ${YELLOW}[U]${NC} ${BOLD}Update${NC}    — Pull the latest index.html from GitHub"
    echo -e "     ${YELLOW}[R]${NC} ${BOLD}Remove${NC}    — Uninstall Climind completely"
    echo -e "     ${YELLOW}[Q]${NC} ${BOLD}Quit${NC}      — Exit"
    echo ""
    echo -n -e "  ${CYAN}➜  Enter choice [S/u/r/q]: ${NC}"
    read -r CHOICE
    CHOICE=$(echo "$CHOICE" | tr '[:upper:]' '[:lower:]')

    case "$CHOICE" in
        s|start|"")
            cd "$INSTALL_DIR"
            ;;
        u|update)
            echo ""
            echo -e "  ${BLUE}⬇  Downloading latest version from GitHub...${NC}"
            mkdir -p "$INSTALL_DIR"
            if command -v curl &> /dev/null; then
                curl -fsSL "$GITHUB_RAW" -o "$INSTALL_DIR/index.html"
            elif command -v wget &> /dev/null; then
                wget -q "$GITHUB_RAW" -O "$INSTALL_DIR/index.html"
            else
                echo -e "  ${RED}✖  curl or wget required for update.${NC}"
                exit 1
            fi
            echo "v5.0.0-$(date +%Y%m%d)" > "$INSTALL_DIR/.version"
            echo -e "  ${GREEN}✓  Updated successfully!${NC}"
            echo ""
            cd "$INSTALL_DIR"
            ;;
        r|remove)
            echo ""
            echo -n -e "  ${RED}${BOLD}⚠  Are you sure you want to remove Climind? [y/N]: ${NC}"
            read -r CONFIRM
            CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
            if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "yes" ]; then
                rm -rf "$INSTALL_DIR"
                echo ""
                echo -e "  ${GREEN}✓  Climind removed from $INSTALL_DIR${NC}"
                echo ""
                exit 0
            else
                echo -e "  ${BLUE}  Cancelled.${NC}"
                exit 0
            fi
            ;;
        q|quit)
            echo ""
            echo -e "  ${BLUE}  Goodbye! 👋${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo -e "  ${RED}  Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac
else
    # ─── Fresh install ───
    echo -e "  ${CYAN}📦  Fresh install detected.${NC}"
    echo ""

    # Check if index.html exists in current dir for offline install
    if [ -f "index.html" ]; then
        echo -e "  ${GREEN}✓  Found index.html in current directory.${NC}"
        mkdir -p "$INSTALL_DIR"
        cp index.html "$INSTALL_DIR/"
    else
        echo -e "  ${BLUE}⬇  Downloading from GitHub...${NC}"
        mkdir -p "$INSTALL_DIR"
        if command -v curl &> /dev/null; then
            curl -fsSL "$GITHUB_RAW" -o "$INSTALL_DIR/index.html"
        elif command -v wget &> /dev/null; then
            wget -q "$GITHUB_RAW" -O "$INSTALL_DIR/index.html"
        else
            echo -e "  ${RED}✖  index.html not found locally and curl/wget not available.${NC}"
            exit 1
        fi
    fi

    echo "v5.0.0-$(date +%Y%m%d)" > "$INSTALL_DIR/.version"
    echo -e "  ${GREEN}✓  Installed to $INSTALL_DIR${NC}"
    echo ""
    cd "$INSTALL_DIR"
fi

# ─── Find free port ───
if command -v lsof &> /dev/null; then
    while lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; do
        PORT=$((PORT + 1))
    done
fi

echo -e "  ${GREEN}✓  Runtime: $SERVER ($VERSION)${NC}"
echo ""
echo -e "${CYAN}${BOLD}  🚀  Launching Climind v5 on http://localhost:$PORT${NC}"
echo -e "${BLUE}      Press Ctrl+C to stop${NC}"
echo -e "${YELLOW}─────────────────────────────────────────────────────────────────────────────────────────────────────${NC}"
echo ""

# ─── Launch server ───
if [ "$SERVER" = "python3" ] || [ "$SERVER" = "python" ]; then
    if $SERVER -m http.server --help &> /dev/null; then
        $SERVER -m http.server $PORT
    else
        $SERVER -m SimpleHTTPServer $PORT
    fi
elif [ "$SERVER" = "node" ]; then
    $SERVER -e "const h=require('http'),f=require('fs'),p=require('path');h.createServer((q,r)=>{let u=q.url==='/'?'index.html':q.url;u=p.join('.',u);f.readFile(u,(e,d)=>{if(e){r.writeHead(404);r.end('404');}else{const x=p.extname(u);const t={'.html':'text/html','.css':'text/css','.js':'application/javascript','.json':'application/json','.png':'image/png','.jpg':'image/jpeg','.svg':'image/svg+xml'}[x]||'text/plain';r.writeHead(200,{'Content-Type':t});r.end(d);}});}).listen($PORT,()=>console.log('Climind v5 running at http://localhost:$PORT'));"
fi
