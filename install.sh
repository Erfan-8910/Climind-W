#!/usr/bin/env bash
# ============================================================
#  Climind v5.1 — Smart Installer / Updater / Remover
#  "Your daily sanctuary" — Weather · Focus · Toolbox
#  https://github.com/Erfan-8910/Climind-W
# ============================================================
set -euo pipefail

# ────────────────────────────────────────────────────────────
#  Constants
# ────────────────────────────────────────────────────────────
APP_NAME="Climind"
APP_VERSION="5.1.0"
REPO="Erfan-8910/Climind-W"
# The current sanctuary release lives on the Version-5.1 branch.
# After merging into main, set CLIMIND_BRANCH=main (or change this default).
BRANCH="${CLIMIND_BRANCH:-Version-5.1}"
RAW_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/index.html"
ISSUES_URL="https://github.com/${REPO}/issues"

INSTALL_DIR="${CLIMIND_DIR:-$HOME/climind}"
PORT=8080
ASSUME_YES=false
ACTION=""

# ────────────────────────────────────────────────────────────
#  Colors & symbols
# ────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  RED='\033[0;31m';    GREEN='\033[0;32m';  BLUE='\033[0;34m'
  CYAN='\033[0;36m';   YELLOW='\033[1;33m'; MAGENTA='\033[0;35m'
  BOLD='\033[1m';      DIM='\033[2m';       NC='\033[0m'
else
  RED=''; GREEN=''; BLUE=''; CYAN=''; YELLOW=''; MAGENTA=''; BOLD=''; DIM=''; NC=''
fi

ok()   { printf '  %b✔%b  %b\n' "${GREEN}${BOLD}" "${NC}" "$1"; }
info() { printf '  %b➜%b  %b\n' "${CYAN}${BOLD}" "${NC}" "$1"; }
warn() { printf '  %b⚠%b  %b\n' "${YELLOW}${BOLD}" "${NC}" "$1"; }
err()  { printf '  %b✖%b  %b\n' "${RED}${BOLD}" "${NC}" "$1" >&2; }
hr()   { printf '%b  ────────────────────────────────────────────────────────────────────────%b\n\n' "${YELLOW}" "${NC}"; }

banner() {
  printf '\n'
  printf '%b' "${CYAN}${BOLD}"
  cat <<'ART'
    ███████╗██████╗ ███████╗ █████╗ ███╗   ██╗    ██████╗██╗     ██╗███╗   ███╗███╗   ██╗██████╗
    ██╔════╝██╔══██╗██╔════╝██╔══██╗████╗  ██║   ██╔════╝██║     ██║████╗ ████║████╗  ██║██╔══██╗
    █████╗  ██████╔╝█████╗  ███████║██╔██╗ ██║   ██║     ██║     ██║██╔████╔██║██╔██╗ ██║██║  ██║
    ██╔══╝  ██╔══██╗██╔══╝  ██╔══██║██║╚██╗██║   ██║     ██║     ██║██║╚██╔╝██║██║╚██╗██║██║  ██║
    ███████╗██║  ██║██║     ██║  ██║██║ ╚████║   ╚██████╗███████╗██║██║ ╚═╝ ██║██║ ╚████║██████╔╝
    ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝    ╚═════╝╚══════╝╚═╝╚═╝     ╚═╝╚═╝  ╚═══╝╚═════╝
ART
  printf '%b\n' "${NC}"
  printf '%b                          v%s  ·  Sanctuary  —  Weather · Focus · Toolbox%b\n\n' "${MAGENTA}" "${APP_VERSION}" "${NC}"
  printf '%b                          Install dir: %s%b\n' "${DIM}" "${INSTALL_DIR}" "${NC}"
  printf '\n'
  hr
}

# ────────────────────────────────────────────────────────────
#  Helpers
# ────────────────────────────────────────────────────────────
fetch() { # fetch <url> <outfile>
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    return 127
  fi
}

detect_runtime() {
  RUNTIME=""
  RUNTIME_VERSION=""
  if command -v python3 >/dev/null 2>&1; then
    RUNTIME="python3"
    RUNTIME_VERSION="$(python3 --version 2>&1 | awk '{print $2}')"
  elif command -v python >/dev/null 2>&1 && python -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' 2>/dev/null; then
    RUNTIME="python"
    RUNTIME_VERSION="$(python --version 2>&1 | awk '{print $2}')"
  elif command -v node >/dev/null 2>&1; then
    RUNTIME="node"
    RUNTIME_VERSION="$(node --version)"
  fi
}

require_runtime() {
  detect_runtime
  if [ -z "${RUNTIME}" ]; then
    err "No server runtime found."
    info "Install Python 3 or Node.js first: https://www.python.org / https://nodejs.org"
    exit 1
  fi
}

installed() {
  [ -f "${INSTALL_DIR}/index.html" ]
}

local_version() {
  if [ -f "${INSTALL_DIR}/.version" ]; then
    head -n1 "${INSTALL_DIR}/.version" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

remote_version() { # downloads index.html to <tmpfile>, echoes version ("5", "5.1", ...)
  local tmp="$1"
  local rv=""
  if fetch "${RAW_URL}" "${tmp}" 2>/dev/null; then
    rv="$(grep -aoE 'Climind[^0-9]{0,3}v?[0-9]+(\.[0-9]+)*' "${tmp}" 2>/dev/null \
      | grep -oE '[0-9]+(\.[0-9]+)*' | head -n1 || true)"
  fi
  echo "${rv}"
}

port_in_use() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -Pi :"$1" -sTCP:LISTEN -t >/dev/null 2>&1
  elif command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | grep -qE "[:.]$1[[:space:]]"
  elif command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null | grep -qE "[:.]$1[[:space:]]"
  else
    return 1
  fi
}

find_free_port() {
  local attempts=0
  while port_in_use "${PORT}" && [ "${attempts}" -lt 100 ]; do
    PORT=$((PORT + 1))
    attempts=$((attempts + 1))
  done
}

confirm() { # confirm <question> → 0=yes
  if [ "${ASSUME_YES}" = true ]; then
    return 0
  fi
  local answer
  printf '  %b%s [y/N]: %b' "${BOLD}" "$1" "${NC}"
  read -r answer || return 1
  answer="$(echo "${answer}" | tr '[:upper:]' '[:lower:]')"
  case "${answer}" in
    y|yes) return 0 ;;
    *)     return 1 ;;
  esac
}

# ────────────────────────────────────────────────────────────
#  Actions
# ────────────────────────────────────────────────────────────
do_check() {
  info "Checking for updates…"
  require_runtime
  local tmp rv current
  tmp="$(mktemp)"
  if ! rv="$(remote_version "${tmp}")" || [ -z "${rv}" ]; then
    warn "Could not determine the remote version (offline? GitHub unreachable?)."
    rm -f "${tmp}"
    return 1
  fi
  lv="$(local_version)"
  current="${lv}"
  printf '\n'
  printf '  %bLocal:%b   %s\n' "${BOLD}" "${NC}" "${current:-not installed}"
  printf '  %bGitHub:%b  v%s (%s branch)\n' "${BOLD}" "${NC}" "${rv}" "${BRANCH}"
  printf '\n'
  if [ -z "${current}" ]; then
    info "Climind is not installed yet — run: ${BOLD}./install.sh install${NC}"
  elif [ "${current#v}" = "${rv}" ]; then
    ok "You are up to date. ✨"
  else
    warn "Update available!  Run: ${BOLD}./install.sh update${NC}"
  fi
  rm -f "${tmp}"
  return 0
}

do_install() {
  require_runtime
  mkdir -p "${INSTALL_DIR}"

  if [ -f "${INSTALL_DIR}/index.html" ] && [ "${ACTION}" = "update" ]; then
    cp "${INSTALL_DIR}/index.html" "${INSTALL_DIR}/index.html.bak" 2>/dev/null || true
    info "Backed up your current copy → index.html.bak"
  fi

  local ver=""
  if [ ! -f "${INSTALL_DIR}/index.html" ] && [ -f "index.html" ]; then
    ok "Found index.html in the current directory — installing offline."
    cp "index.html" "${INSTALL_DIR}/index.html"
  else
    info "Downloading the latest Climind from GitHub (${BRANCH} branch)…"
    if ! fetch "${RAW_URL}" "${INSTALL_DIR}/index.html.tmp"; then
      err "Download failed. Check your internet connection and try again."
      rm -f "${INSTALL_DIR}/index.html.tmp"
      exit 1
    fi
    mv "${INSTALL_DIR}/index.html.tmp" "${INSTALL_DIR}/index.html"
  fi

  # Stamp the installed version (detected from the file itself when possible)
  ver="$(grep -aoE 'Climind[^0-9]{0,3}v?[0-9]+(\.[0-9]+)*' "${INSTALL_DIR}/index.html" 2>/dev/null \
    | grep -oE '[0-9]+(\.[0-9]+)*' | head -n1 || true)"
  [ -z "${ver}" ] && ver="${APP_VERSION%.*}"
  printf 'v%s\n%s\n' "${ver}" "$(date +%Y-%m-%d)" > "${INSTALL_DIR}/.version"

  if [ "${ACTION}" = "update" ]; then
    ok "Updated to v${ver} → ${INSTALL_DIR}"
  else
    ok "Installed v${ver} → ${INSTALL_DIR}"
  fi
  printf '\n  %bLaunch it now:%b  %b./install.sh start%b\n\n' "${DIM}" "${NC}" "${CYAN}${BOLD}" "${NC}"
}

do_start() {
  installed || { warn "Climind is not installed yet."; ACTION="install"; do_install; }
  require_runtime
  find_free_port
  cd "${INSTALL_DIR}"

  ok "Runtime: ${RUNTIME} (${RUNTIME_VERSION})"
  printf '\n'
  printf '%b  🚀  Launching Climind v%s on http://localhost:%s%b\n' "${CYAN}${BOLD}" "${APP_VERSION%.*}" "${PORT}" "${NC}"
  printf '%b      Press Ctrl+C to stop%b\n\n' "${DIM}" "${NC}"
  hr

  trap 'printf "\n%b  Server stopped. See you soon! 👋%b\n\n" "${DIM}" "${NC}"; exit 0' INT TERM

  if [ "${RUNTIME}" = "python3" ] || [ "${RUNTIME}" = "python" ]; then
    exec "${RUNTIME}" -m http.server "${PORT}"
  elif [ "${RUNTIME}" = "node" ]; then
    exec node -e "const h=require('http'),f=require('fs'),p=require('path');h.createServer((q,r)=>{let u=q.url==='/'?'index.html':q.url;u=p.join('.',u);f.readFile(u,(e,d)=>{if(e){r.writeHead(404);r.end('404');}else{const x=p.extname(u);const t={'.html':'text/html','.css':'text/css','.js':'application/javascript','.json':'application/json','.png':'image/png','.jpg':'image/jpeg','.svg':'image/svg+xml'}[x]||'text/plain';r.writeHead(200,{'Content-Type':t});r.end(d);}});}).listen(${PORT},()=>console.log('Climind running at http://localhost:${PORT}'));"
  fi
}

do_remove() {
  if ! installed; then
    warn "Climind is not installed in ${INSTALL_DIR}. Nothing to do."
    return 0
  fi
  if confirm "Remove Climind completely from ${INSTALL_DIR}?"; then
    rm -rf "${INSTALL_DIR}"
    ok "Climind removed. Goodbye! 👋"
  else
    info "Cancelled — your sanctuary stays right where it is."
  fi
}

menu() {
  if installed; then
    local current
    current="$(local_version)"
    printf '  %b✔ Climind is already installed%b %b(version: %s)%b\n\n' "${GREEN}${BOLD}" "${NC}" "${DIM}" "${current:-unknown}" "${NC}"
    printf '  %bWhat would you like to do?%b\n\n' "${CYAN}${BOLD}"
    printf '     %b[S]%b %bStart%b     — launch the local server\n' "${YELLOW}" "${NC}" "${BOLD}" "${NC}"
    printf '     %b[U]%b %bUpdate%b    — pull the latest version from GitHub\n' "${YELLOW}" "${NC}" "${BOLD}" "${NC}"
    printf '     %b[C]%b %bCheck%b     — compare installed vs. latest\n' "${YELLOW}" "${NC}" "${BOLD}" "${NC}"
    printf '     %b[R]%b %bRemove%b    — uninstall Climind\n' "${YELLOW}" "${NC}" "${BOLD}" "${NC}"
    printf '     %b[Q]%b %bQuit%b      — exit\n\n' "${YELLOW}" "${NC}" "${BOLD}" "${NC}"
    local choice
    printf '  %b➜  Enter choice [S/u/c/r/q]: %b' "${CYAN}" "${NC}"
    read -r choice || choice="q"
    choice="$(echo "${choice}" | tr '[:upper:]' '[:lower:]')"
    case "${choice}" in
      s|start|"") ACTION="start" ;;
      u|update)   ACTION="update" ;;
      c|check)    ACTION="check" ;;
      r|remove)   ACTION="remove" ;;
      q|quit)     printf '\n  %bGoodbye! 👋%b\n\n' "${DIM}" "${NC}"; exit 0 ;;
      *)          err "Invalid choice."; exit 1 ;;
    esac
  else
    info "Fresh install detected — installing Climind…"
    printf '\n'
    ACTION="install"
  fi
}

usage() {
  cat <<EOF

  ${BOLD}Climind v${APP_VERSION} — Smart Installer${NC}  ${DIM}"Your daily sanctuary"${NC}

  ${BOLD}Usage:${NC}
    ./install.sh [action] [options]

  ${BOLD}Actions:${NC}
    install        Fresh install to ${INSTALL_DIR}
    start          Launch the local server (default when already installed)
    update         Download the latest version (backs up the old copy)
    check          Compare your installed version vs. GitHub
    remove         Uninstall completely

  ${BOLD}Options:${NC}
    --dir <path>   Install directory      (env: CLIMIND_DIR, default: ~/climind)
    --port <n>     Force a port          (default: 8080, auto-finds a free one)
    --yes          Skip confirmation prompts
    --version      Print installer version
    --help         Show this help

  ${BOLD}Examples:${NC}
    ./install.sh                          # interactive menu
    ./install.sh install --dir ~/apps/climind
    ./install.sh update --yes
    CLIMIND_DIR=/opt/climind ./install.sh start

  ${DIM}More info: https://github.com/${REPO}${NC}

EOF
}

# ────────────────────────────────────────────────────────────
#  Argument parsing
# ────────────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    install|start|update|check|remove)
      ACTION="$1"; shift ;;
    --dir)
      [ $# -ge 2 ] || { err "--dir requires a path."; exit 1; }
      INSTALL_DIR="$2"; shift 2 ;;
    --port)
      [ $# -ge 2 ] || { err "--port requires a number."; exit 1; }
      PORT="$2"; shift 2 ;;
    --yes|-y)
      ASSUME_YES=true; shift ;;
    --version|-v)
      echo "Climind installer v${APP_VERSION}"; exit 0 ;;
    --help|-h)
      [ -t 1 ] && banner
      usage; exit 0 ;;
    *)
      err "Unknown option: $1"
      usage; exit 1 ;;
  esac
done

# Pretty banner (only in interactive terminals)
if [ -t 1 ]; then
  if [ -t 0 ]; then clear 2>/dev/null || true; fi
  banner
fi

# Default behavior:
#   • interactive terminal → menu
#   • piped (curl | bash)  → install straight away
if [ -z "${ACTION}" ]; then
  if [ -t 0 ]; then
    menu
  else
    ACTION="install"
  fi
fi

case "${ACTION}" in
  install) do_install ;;
  update)  do_install ;;
  start)   do_start ;;
  check)   do_check ;;
  remove)  do_remove ;;
esac
