#!/usr/bin/env bash
#
# setup-macos.sh — Deja un Mac (Apple Silicon o Intel) listo para desarrollo
# Laravel profesional con DDEV: Homebrew, Docker, DDEV, mkcert (SSL local),
# Node vía nvm, PHP + Composer nativos de conveniencia, GitHub CLI y VS Code.
#
# Idempotente: puedes correrlo todas las veces que quieras; salta lo ya instalado.
#
# Uso:
#   bash setup.sh          (detecta macOS y llega aquí)
#   bash setup-macos.sh    (equivalente, directo)
#
# Toggles (pon la variable en 0 para saltar esa sección):
#   INSTALL_NATIVE_PHP=0   sin PHP CLI + Composer nativos
#   INSTALL_GH=0           sin GitHub CLI
#   INSTALL_IDES=0         sin VS Code
#   INSTALL_VSCODE_EXTS=0  sin extensiones de VS Code
#
# Proveedor de Docker (en macOS el motor corre en una VM; hay varias apps).
# Si ya tienes uno funcionando se respeta y no se instala nada. Sin variable,
# usa el que ya esté instalado (aunque esté apagado) o, si no hay ninguno,
# Docker Desktop:
#   DOCKER_PROVIDER=docker-desktop  la app oficial de Docker
#   DOCKER_PROVIDER=colima          libre/open source, por terminal, sin GUI
#   DOCKER_PROVIDER=orbstack        el más rápido; de pago para uso comercial

set -euo pipefail

INSTALL_NATIVE_PHP=${INSTALL_NATIVE_PHP:-1}
INSTALL_GH=${INSTALL_GH:-1}
INSTALL_IDES=${INSTALL_IDES:-1}
INSTALL_VSCODE_EXTS=${INSTALL_VSCODE_EXTS:-1}
DOCKER_PROVIDER=${DOCKER_PROVIDER:-}

AZUL='\033[1;34m'; VERDE='\033[1;32m'; AMARILLO='\033[1;33m'; SC='\033[0m'
paso()  { printf "\n${AZUL}==> %s${SC}\n" "$*"; }
ok()    { printf "${VERDE}    ✔ %s${SC}\n" "$*"; }
aviso() { printf "${AMARILLO}    ⚠ %s${SC}\n" "$*"; }
# los casks modifican apps en /Applications; desde macOS Ventura eso requiere
# que el Terminal tenga el permiso "Gestión de apps" (sudo no lo reemplaza)
fallo_cask() {
  aviso "brew no pudo instalar $1 ('Operation not permitted' = falta un permiso de macOS)."
  aviso "Ajustes del Sistema → Privacidad y seguridad → Gestión de apps → activa tu"
  aviso "Terminal, reábrelo y re-corre: bash setup.sh"
  exit 1
}

# ------------------------------------------------------------------ chequeos
if [ "$(uname -s)" != "Darwin" ]; then
  echo "Este script es para macOS; en Ubuntu/Linux usa: bash setup.sh"
  exit 1
fi
if [ "$(id -u)" -eq 0 ]; then
  echo "Córrelo como tu usuario normal (usa sudo internamente), no como root."
  exit 1
fi
ARCH=$(uname -m)   # arm64 (Apple Silicon) | x86_64 (Intel)
RAIZ_REPO=$(cd -- "$(dirname -- "$0")" && pwd)

paso "Autorización sudo (se pide una sola vez)"
sudo -v
# mantiene vivo el timestamp de sudo mientras corre el script
( while true; do sudo -n true 2>/dev/null || true; sleep 60; done ) & SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT

# ------------------------------------------------------------------ clt
paso "Xcode Command Line Tools (git y compiladores de Apple)"
if xcode-select -p >/dev/null 2>&1; then
  ok "ya instaladas"
else
  xcode-select --install 2>/dev/null || true
  aviso "Acepta el diálogo de Apple que acaba de abrirse y espera a que termine..."
  until xcode-select -p >/dev/null 2>&1; do sleep 10; done
  ok "Command Line Tools instaladas"
fi

# ------------------------------------------------------------------ homebrew
paso "Homebrew (gestor de paquetes de macOS)"
if [ "$ARCH" = "arm64" ]; then BREW_PREFIX=/opt/homebrew; else BREW_PREFIX=/usr/local; fi
if ! command -v brew >/dev/null 2>&1 && [ -x "$BREW_PREFIX/bin/brew" ]; then
  eval "$("$BREW_PREFIX/bin/brew" shellenv)"
fi
if command -v brew >/dev/null 2>&1; then
  ok "ya instalado: $(brew --version | head -1)"
else
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$("$BREW_PREFIX/bin/brew" shellenv)"
  ok "homebrew instalado"
fi
if ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
  printf '\neval "$(%s/bin/brew shellenv)"\n' "$BREW_PREFIX" >> "$HOME/.zprofile"
  ok "brew agregado al PATH (~/.zprofile)"
fi

# ------------------------------------------------------------------ base
paso "Paquetes base"
brew install git jq nss   # nss: que Firefox también confíe en la CA de mkcert
ok "paquetes base"

# ------------------------------------------------------------------ docker
if [ -z "$DOCKER_PROVIDER" ]; then
  if [ -d /Applications/OrbStack.app ]; then DOCKER_PROVIDER=orbstack
  elif [ -d /Applications/Docker.app ]; then DOCKER_PROVIDER=docker-desktop
  elif command -v colima >/dev/null 2>&1; then DOCKER_PROVIDER=colima
  else DOCKER_PROVIDER=docker-desktop
  fi
fi
paso "Docker (proveedor: ${DOCKER_PROVIDER})"
if docker info >/dev/null 2>&1; then
  ok "ya hay un Docker funcionando: $(docker --version)"
else
  case "$DOCKER_PROVIDER" in
    docker-desktop)
      if [ ! -d /Applications/Docker.app ]; then
        brew install --cask docker-desktop || fallo_cask "Docker Desktop"
      fi
      open -a Docker
      aviso "Primera vez: acepta el asistente de Docker Desktop (términos y permisos)."
      ;;
    orbstack)
      if [ ! -d /Applications/OrbStack.app ]; then
        brew install --cask orbstack || fallo_cask "OrbStack"
      fi
      open -a OrbStack
      ;;
    colima)
      brew install colima docker
      colima start --cpu 4 --memory 6
      brew services start colima >/dev/null 2>&1 || true   # arranca al iniciar sesión
      ;;
    *)
      echo "DOCKER_PROVIDER desconocido: '${DOCKER_PROVIDER}' (usa docker-desktop, colima u orbstack)"
      exit 1
      ;;
  esac
  printf '    esperando a que Docker responda (el primer arranque puede tardar varios minutos)'
  for _ in $(seq 1 120); do
    if docker info >/dev/null 2>&1; then break; fi
    printf '.'; sleep 5
  done
  echo
  if ! docker info >/dev/null 2>&1; then
    aviso "Docker aún no responde. Termina el asistente de la app y re-corre: bash setup.sh"
    exit 1
  fi
fi
ok "docker listo: $(docker --version)"

# ------------------------------------------------------------------ ddev
paso "DDEV"
if command -v ddev >/dev/null 2>&1; then
  ok "ya instalado: $(ddev --version)"
else
  brew install ddev/ddev/ddev
fi
# sin telemetría ni preguntas la primera vez
ddev config global --instrumentation-opt-in=false >/dev/null 2>&1 || true
ok "ddev listo"
if command -v valet >/dev/null 2>&1 || [ -d "$HOME/.config/valet" ]; then
  aviso "Laravel Valet detectado: su nginx ocupa 127.0.0.1:80/443, así que DDEV usará"
  aviso "puertos alternativos (p. ej. https://<proyecto>.ddev.site:33001). Funciona igual;"
  aviso "para URLs sin puerto: valet stop   ('valet start' lo revierte)"
fi

# ------------------------------------------------------------------ mkcert
paso "mkcert (SSL local confiable para *.ddev.site)"
if ! command -v mkcert >/dev/null 2>&1; then
  brew install mkcert
fi
mkcert -install   # agrega la CA al Llavero (puede pedir tu clave)
ok "CA local instalada; los navegadores confiarán en https://*.ddev.site"

# ------------------------------------------------------------------ node
paso "Node.js LTS (vía nvm) + npm + corepack"
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  NVM_TAG=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name // empty')
  if [ -z "$NVM_TAG" ]; then NVM_TAG="v0.40.1"; fi
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_TAG}/install.sh" | bash
fi
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default 'lts/*' >/dev/null
corepack enable >/dev/null 2>&1 || true
ok "node $(node -v) / npm $(npm -v)"

# ------------------------------------------------------------------ php nativo
if [ "$INSTALL_NATIVE_PHP" = "1" ]; then
  paso "PHP CLI + Composer nativos (conveniencia; las versiones por proyecto viven en DDEV)"
  brew install php composer   # el php de brew ya trae mbstring, intl, gd, etc.
  ok "php $(php -r 'echo PHP_VERSION;') + $(composer --version --no-ansi 2>/dev/null | head -1 || echo 'composer no instalado')"
fi

# ------------------------------------------------------------------ github cli
if [ "$INSTALL_GH" = "1" ]; then
  paso "GitHub CLI"
  if command -v gh >/dev/null 2>&1; then
    ok "ya instalado: $(gh --version | head -1)"
  else
    brew install gh
  fi
fi

# ------------------------------------------------------------------ IDEs
if [ "$INSTALL_IDES" = "1" ]; then
  paso "IDEs"
  if command -v code >/dev/null 2>&1 || [ -d "/Applications/Visual Studio Code.app" ]; then
    ok "VS Code ya instalado"
  else
    brew install --cask visual-studio-code || fallo_cask "VS Code"
    ok "VS Code instalado"
  fi
  if [ -d "/Applications/PhpStorm.app" ] || [ -d "$HOME/Applications/PhpStorm.app" ] || [ -d "/Applications/JetBrains Toolbox.app" ]; then
    ok "PhpStorm / JetBrains Toolbox detectado"
  else
    aviso "PhpStorm no detectado: instálalo con JetBrains Toolbox → https://www.jetbrains.com/toolbox-app/"
  fi
fi

# si VS Code se instaló a mano, el comando 'code' puede no estar en el PATH
CODE_BIN=$(command -v code || true)
if [ -z "$CODE_BIN" ] && [ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]; then
  CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
fi
if [ "$INSTALL_VSCODE_EXTS" = "1" ] && [ -n "$CODE_BIN" ]; then
  paso "Extensiones VS Code (PHP, Xdebug, Laravel, Vue)"
  for ext in xdebug.php-debug bmewburn.vscode-intelephense-client laravel.vscode-laravel Vue.volar EditorConfig.EditorConfig; do
    "$CODE_BIN" --install-extension "$ext" >/dev/null 2>&1 && ok "$ext" || aviso "no pude instalar $ext"
  done
fi

# ------------------------------------------------------------------ git + PATH
paso "Git y helpers"
git config --global init.defaultBranch main
if [ -z "$(git config --global user.name 2>/dev/null || true)" ]; then
  aviso "Falta tu identidad git:  git config --global user.name 'Tu Nombre' && git config --global user.email 'tu@correo'"
else
  ok "identidad git: $(git config --global user.name) <$(git config --global user.email)>"
fi
if ! ls "$HOME"/.ssh/id_* >/dev/null 2>&1; then
  aviso "Sin llaves SSH: restaura tu respaldo o crea una:  ssh-keygen -t ed25519 -C 'tu@correo'"
fi
RC="$HOME/.zshrc"   # shell por defecto en macOS
case "${SHELL##*/}" in bash) RC="$HOME/.bash_profile" ;; esac
if ! grep -qF "${RAIZ_REPO}/bin" "$RC" 2>/dev/null; then
  printf '\n# helpers laravel-ddev-kit (new-laravel, adopt-laravel, backup-projects)\nexport PATH="$PATH:%s/bin"\n' "$RAIZ_REPO" >> "$RC"
  ok "agregué ${RAIZ_REPO}/bin al PATH (abre una terminal nueva)"
fi

# ------------------------------------------------------------------ resumen
paso "¡Mac lista!"
cat <<RESUMEN

  Instalado: homebrew, docker (${DOCKER_PROVIDER}), ddev, mkcert (CA local), node/npm (nvm), php+composer, gh

  Crear proyecto Laravel nuevo:    new-laravel <nombre> [php] [node] [mysql]
  Adoptar proyecto existente:      cd proyecto && adopt-laravel
  Respaldar BDs antes de formatear: backup-projects

  Guía completa: ${RAIZ_REPO}/README.md

RESUMEN
