#!/usr/bin/env bash
#
# setup-ubuntu.sh — Deja una máquina Ubuntu recién instalada lista para desarrollo
# Laravel profesional con DDEV: Docker, DDEV, mkcert (SSL local), Node vía nvm,
# PHP + Composer nativos de conveniencia, GitHub CLI y VS Code.
#
# Idempotente: puedes correrlo todas las veces que quieras; salta lo ya instalado.
#
# Uso:
#   bash setup.sh          (detecta Linux y llega aquí)
#   bash setup-ubuntu.sh   (equivalente, directo)
#
# Toggles (pon la variable en 0 para saltar esa sección):
#   INSTALL_NATIVE_PHP=0   sin PHP CLI + Composer nativos
#   INSTALL_GH=0           sin GitHub CLI
#   INSTALL_IDES=0         sin VS Code
#   INSTALL_VSCODE_EXTS=0  sin extensiones de VS Code
#
# Si Docker aún no publica paquetes para tu versión de Ubuntu:
#   DOCKER_CODENAME=noble bash setup.sh

set -euo pipefail

INSTALL_NATIVE_PHP=${INSTALL_NATIVE_PHP:-1}
INSTALL_GH=${INSTALL_GH:-1}
INSTALL_IDES=${INSTALL_IDES:-1}
INSTALL_VSCODE_EXTS=${INSTALL_VSCODE_EXTS:-1}

AZUL='\033[1;34m'; VERDE='\033[1;32m'; AMARILLO='\033[1;33m'; SC='\033[0m'
paso()  { printf "\n${AZUL}==> %s${SC}\n" "$*"; }
ok()    { printf "${VERDE}    ✔ %s${SC}\n" "$*"; }
aviso() { printf "${AMARILLO}    ⚠ %s${SC}\n" "$*"; }

# ------------------------------------------------------------------ chequeos
if [ "$(id -u)" -eq 0 ]; then
  echo "Córrelo como tu usuario normal (usa sudo internamente), no como root."
  exit 1
fi
. /etc/os-release
if [ "${ID:-}" != "ubuntu" ]; then
  aviso "Pensado para Ubuntu; detectado '${ID:-desconocido}'. Continúo igual..."
fi
ARCH=$(dpkg --print-architecture)
RAIZ_REPO=$(cd -- "$(dirname -- "$0")" && pwd)
NECESITA_RELOGIN=0

paso "Autorización sudo (se pide una sola vez)"
sudo -v
# mantiene vivo el timestamp de sudo mientras corre el script
( while true; do sudo -n true 2>/dev/null || true; sleep 60; done ) & SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT

# ------------------------------------------------------------------ base
paso "Paquetes base"
sudo apt-get update -y
sudo apt-get install -y curl wget git unzip zip ca-certificates gnupg jq \
  build-essential libnss3-tools apt-transport-https
ok "paquetes base"

# ------------------------------------------------------------------ docker
paso "Docker Engine"
if command -v docker >/dev/null 2>&1; then
  ok "ya instalado: $(docker --version)"
else
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  # usa el primer codename para el que Docker ya publique paquetes
  CODENAME=""
  for cand in "${DOCKER_CODENAME:-}" "${UBUNTU_CODENAME:-$VERSION_CODENAME}" noble jammy; do
    if [ -z "$cand" ]; then continue; fi
    if curl -fsSL --head "https://download.docker.com/linux/ubuntu/dists/${cand}/Release" >/dev/null 2>&1; then
      CODENAME="$cand"
      break
    fi
  done
  if [ -z "$CODENAME" ]; then
    echo "No pude determinar un codename de Ubuntu soportado por Docker."
    exit 1
  fi
  if [ "$CODENAME" != "${UBUNTU_CODENAME:-$VERSION_CODENAME}" ]; then
    aviso "Docker no publica aún para tu Ubuntu; uso paquetes de '${CODENAME}'"
  fi
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
sudo systemctl enable --now docker
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
  NECESITA_RELOGIN=1
fi
ok "docker listo"

# ------------------------------------------------------------------ ddev
paso "DDEV"
if command -v ddev >/dev/null 2>&1; then
  ok "ya instalado: $(ddev --version)"
else
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://pkg.ddev.com/apt/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/ddev.gpg > /dev/null
  sudo chmod a+r /etc/apt/keyrings/ddev.gpg
  echo "deb [signed-by=/etc/apt/keyrings/ddev.gpg] https://pkg.ddev.com/apt/ * *" \
    | sudo tee /etc/apt/sources.list.d/ddev.list > /dev/null
  sudo apt-get update -y
  sudo apt-get install -y ddev
fi
# sin telemetría ni preguntas la primera vez
ddev config global --instrumentation-opt-in=false >/dev/null 2>&1 || true
ok "ddev listo"

# ------------------------------------------------------------------ mkcert
paso "mkcert (SSL local confiable para *.ddev.site)"
if ! command -v mkcert >/dev/null 2>&1; then
  if ! sudo apt-get install -y mkcert; then
    aviso "mkcert no está en apt; descargo el binario oficial"
    MK_URL=$(curl -fsSL https://api.github.com/repos/FiloSottile/mkcert/releases/latest \
      | jq -r --arg a "linux-${ARCH}" '.assets[] | select(.name | endswith($a)) | .browser_download_url')
    sudo curl -fsSL "$MK_URL" -o /usr/local/bin/mkcert
    sudo chmod +x /usr/local/bin/mkcert
  fi
fi
mkcert -install
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
  sudo apt-get install -y php-cli php-curl php-mbstring php-xml php-zip php-intl \
    php-mysql php-sqlite3 php-gd php-bcmath
  if ! command -v composer >/dev/null 2>&1; then
    FIRMA_ESPERADA=$(curl -fsSL https://composer.github.io/installer.sig)
    php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
    FIRMA_REAL=$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")
    if [ "$FIRMA_ESPERADA" = "$FIRMA_REAL" ]; then
      sudo php /tmp/composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
    else
      aviso "La firma del instalador de Composer no coincide; lo omito (instálalo a mano)"
    fi
    rm -f /tmp/composer-setup.php
  fi
  ok "php $(php -r 'echo PHP_VERSION;') + $(composer --version --no-ansi 2>/dev/null | head -1 || echo 'composer no instalado')"
fi

# ------------------------------------------------------------------ github cli
if [ "$INSTALL_GH" = "1" ]; then
  paso "GitHub CLI"
  if command -v gh >/dev/null 2>&1; then
    ok "ya instalado: $(gh --version | head -1)"
  else
    sudo apt-get install -y gh || aviso "gh no disponible en apt; instálalo desde https://cli.github.com"
  fi
fi

# ------------------------------------------------------------------ IDEs
if [ "$INSTALL_IDES" = "1" ]; then
  paso "IDEs"
  if command -v code >/dev/null 2>&1; then
    ok "VS Code ya instalado"
  else
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
      | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y code
    ok "VS Code instalado"
  fi
  if command -v phpstorm >/dev/null 2>&1 || [ -d "$HOME/.local/share/JetBrains" ]; then
    ok "PhpStorm / JetBrains Toolbox detectado"
  else
    aviso "PhpStorm no detectado: instálalo con JetBrains Toolbox → https://www.jetbrains.com/toolbox-app/"
  fi
fi

if [ "$INSTALL_VSCODE_EXTS" = "1" ] && command -v code >/dev/null 2>&1; then
  paso "Extensiones VS Code (PHP, Xdebug, Laravel, Vue)"
  for ext in xdebug.php-debug bmewburn.vscode-intelephense-client laravel.vscode-laravel Vue.volar EditorConfig.EditorConfig; do
    code --install-extension "$ext" >/dev/null 2>&1 && ok "$ext" || aviso "no pude instalar $ext"
  done
fi

# ------------------------------------------------------------------ sistema
paso "Ajustes de sistema para desarrollo"
echo 'fs.inotify.max_user_watches=524288' | sudo tee /etc/sysctl.d/60-dev-inotify.conf > /dev/null
sudo sysctl --system > /dev/null
ok "inotify ampliado (watchers para Vite/HMR en proyectos grandes)"

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
if ! grep -qF "${RAIZ_REPO}/bin" "$HOME/.bashrc" 2>/dev/null; then
  printf '\n# helpers laravel-ddev-kit (new-laravel, adopt-laravel, backup-projects)\nexport PATH="$PATH:%s/bin"\n' "$RAIZ_REPO" >> "$HOME/.bashrc"
  ok "agregué ${RAIZ_REPO}/bin al PATH (abre una terminal nueva)"
fi

# ------------------------------------------------------------------ resumen
paso "¡Máquina lista!"
cat <<RESUMEN

  Instalado: docker, ddev, mkcert (CA local), node/npm (nvm), php+composer, gh

  Crear proyecto Laravel nuevo:    new-laravel <nombre> [php] [node] [mysql]
  Adoptar proyecto existente:      cd proyecto && adopt-laravel
  Respaldar BDs antes de formatear: backup-projects

  Guía completa: ${RAIZ_REPO}/README.md

RESUMEN
if [ "$NECESITA_RELOGIN" = "1" ]; then
  aviso "IMPORTANTE: cierra sesión y vuelve a entrar (o reinicia) para usar docker sin sudo."
fi
