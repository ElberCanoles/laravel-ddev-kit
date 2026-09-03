#!/usr/bin/env bash
#
# setup-debian.sh — Deja una máquina Linux de la familia Debian recién instalada
# (Debian, Ubuntu o derivados: Linux Mint, Pop!_OS, LMDE, Kali…) lista para
# desarrollo Laravel profesional con DDEV: Docker, DDEV, mkcert (SSL local),
# Node vía nvm, PHP + Composer nativos de conveniencia, GitHub CLI y VS Code.
#
# Idempotente: puedes correrlo todas las veces que quieras; salta lo ya instalado.
# Guarda un log de cada corrida en ~/.laravel-ddev-kit/ (útil si algo falla).
#
# Uso:
#   bash setup.sh          (detecta Linux y llega aquí)
#   bash setup-debian.sh   (equivalente, directo)
#   bash setup-debian.sh --help
#
# Toggles (pon la variable en 0 para saltar esa sección):
#   INSTALL_DOCKER=0       sin Docker Engine (ya tienes otro, o estás en CI)
#   INSTALL_NATIVE_PHP=0   sin PHP CLI + Composer nativos
#   INSTALL_GH=0           sin GitHub CLI
#   INSTALL_IDES=0         sin VS Code
#   INSTALL_VSCODE_EXTS=0  sin extensiones de VS Code
#
# Docker publica paquetes por versión (codename) de Debian y de Ubuntu. El script
# detecta la tuya —o la base de tu derivado— y, si aún no hay paquetes para ella,
# cae a la última estable. Para forzar una a mano:
#   DOCKER_CODENAME=noble bash setup.sh     (Ubuntu)
#   DOCKER_CODENAME=trixie bash setup.sh    (Debian)
#
# WSL (Windows) no está soportado todavía: KIT_WSL=1 bash setup.sh lo fuerza bajo tu cuenta.

set -euo pipefail

RAIZ_REPO=$(cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=lib/comun.sh
. "$RAIZ_REPO/lib/comun.sh"
# shellcheck source=lib/distro.sh
. "$RAIZ_REPO/lib/distro.sh"
# shellcheck source=lib/instalador.sh
. "$RAIZ_REPO/lib/instalador.sh"

case "${1:-}" in
  -h | --help)
    mostrar_ayuda "$0"
    exit 0
    ;;
esac

INSTALL_DOCKER=${INSTALL_DOCKER:-1}
INSTALL_NATIVE_PHP=${INSTALL_NATIVE_PHP:-1}
INSTALL_GH=${INSTALL_GH:-1}
INSTALL_IDES=${INSTALL_IDES:-1}
INSTALL_VSCODE_EXTS=${INSTALL_VSCODE_EXTS:-1}

# ------------------------------------------------------------------ chequeos
if [ "$(id -u)" -eq 0 ]; then
  echo "Córrelo como tu usuario normal (usa sudo internamente), no como root."
  exit 1
fi
if ! detectar_familia_debian; then
  echo "Este kit soporta Linux de la familia Debian: Debian, Ubuntu y sus derivados"
  echo "(Linux Mint, Pop!_OS, Zorin, elementary, LMDE, Kali…)."
  echo "Detecté '${PRETTY_NAME:-${ID:-desconocido}}', que es de otra familia (Fedora/RHEL, Arch,"
  echo "openSUSE…) y por ahora no está soportada."
  exit 1
fi
# WSL (Windows) todavía no está soportado: el navegador vive en Windows, así que la
# CA de mkcert hay que instalarla allá, y Docker y systemd se configuran distinto.
if grep -qi microsoft /proc/version 2>/dev/null && [ "${KIT_WSL:-0}" != "1" ]; then
  echo "Estás en WSL y este kit aún no lo soporta: el navegador corre en Windows, así que la CA"
  echo "de mkcert hay que instalarla allá, y Docker y systemd se configuran distinto."
  echo "Guía oficial: https://docs.ddev.com/en/stable/users/install/ddev-installation/#windows"
  echo "Si sabes lo que haces y quieres correrlo igual:  KIT_WSL=1 bash setup.sh"
  exit 1
fi
ARCH=$(dpkg --print-architecture)
NECESITA_RELOGIN=0

kit_log_iniciar setup-debian
trap 'kit_trap_error $LINENO "$BASH_COMMAND"' ERR
paso "Sistema detectado"
ok "${PRETTY_NAME:-${ID:-Linux}} (familia ${FAMILIA})"
ok "log de esta corrida: ${KIT_LOG}"

paso "Autorización sudo (se pide una sola vez)"
if ! command -v sudo >/dev/null 2>&1; then
  echo "Falta 'sudo' (pasa en Debian cuando defines clave de root al instalar). Como root (su -):"
  echo "    apt-get install -y sudo && usermod -aG sudo ${USER}"
  echo "Luego cierra sesión, vuelve a entrar y re-corre: bash setup.sh"
  exit 1
fi
if ! sudo -v; then
  echo "Tu usuario no puede usar sudo. Como root (su -):  usermod -aG sudo ${USER}  y vuelve a iniciar sesión."
  exit 1
fi
# mantiene vivo el timestamp de sudo mientras corre el script
(while true; do
  sudo -n true 2>/dev/null || true
  sleep 60
done) &
SUDO_PID=$!
al_salir() {
  kill "$SUDO_PID" 2>/dev/null || true
  sleep 0.3 # deja que el log termine de escribirse
}
trap al_salir EXIT
# apt sin diálogos: ni preguntas de configuración ni el menú de needrestart
# (Ubuntu Server) a mitad de camino. Las variables van tras sudo porque sudo
# limpia el entorno.
apt_get() { sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get "$@"; }

# ------------------------------------------------------------------ base
paso "Paquetes base"
# Debian instalado desde CD/USB deja la fuente 'cdrom:' activa y apt-get update
# se queda pidiendo el disco. Se comenta la línea y queda copia en *.kit-bak.
CON_CDROM=$(grep -lsE '^deb cdrom:' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null || true)
if [ -n "$CON_CDROM" ]; then
  for f in $CON_CDROM; do
    sudo sed -i.kit-bak -E 's/^(deb cdrom:)/# \1/' "$f"
  done
  aviso "Desactivé la fuente apt 'cdrom:' (copia en *.kit-bak): sin eso apt-get update pedía el disco de instalación"
fi
if grep -qs '^URIs: cdrom:' /etc/apt/sources.list.d/*.sources 2>/dev/null; then
  aviso "Hay una fuente apt 'cdrom:' en formato deb822 (/etc/apt/sources.list.d/*.sources); si apt-get update pide el disco, agrégale 'Enabled: no'"
fi
apt_get update -y
apt_get install -y curl wget git unzip zip ca-certificates gnupg jq \
  build-essential libnss3-tools apt-transport-https
ok "paquetes base"

# ------------------------------------------------------------------ repositorios
# Se registran de una vez todos los repos que falten y se hace UN solo apt-get update.
paso "Repositorios apt"
sudo install -m 0755 -d /etc/apt/keyrings
REPOS_NUEVOS=0
INSTALAR_DOCKER_CE=0
INSTALAR_DDEV=0
INSTALAR_CODE=0
if [ "$INSTALL_DOCKER" = 1 ]; then
  if snap list docker >/dev/null 2>&1; then
    echo "Tienes el Docker de snap. Va confinado y DDEV no funciona bien con él; DDEV recomienda"
    echo "Docker CE del repositorio oficial, que es lo que instala este kit."
    echo "Quítalo y vuelve a correr el instalador:   sudo snap remove docker"
    exit 1
  fi
  if command -v docker >/dev/null 2>&1; then
    ok "docker ya instalado: $(docker --version)"
    if dpkg -s docker.io >/dev/null 2>&1; then
      aviso "Es el paquete docker.io de la distro, no Docker CE. Funciona, pero DDEV recomienda el repo oficial (más nuevo, con compose y buildx)"
    fi
  else
    INSTALAR_DOCKER_CE=1
    BASE=$(codename_base "$FAMILIA")
    if ! CODENAME=$(elegir_codename_docker "$FAMILIA" "$BASE" "${VERSION_CODENAME:-}" "${DOCKER_CODENAME:-}"); then
      echo "No encontré paquetes de Docker para tu sistema (familia ${FAMILIA}, base '${BASE:-desconocida}')."
      echo "Fuerza uno a mano: DOCKER_CODENAME=<codename> bash setup.sh"
      exit 1
    fi
    if [ -n "${DOCKER_CODENAME:-}" ] && [ "$CODENAME" = "$DOCKER_CODENAME" ]; then
      ok "Docker: uso el codename que indicaste: '${CODENAME}'"
    elif [ -z "$BASE" ]; then
      aviso "No pude detectar en qué versión de ${FAMILIA} se basa tu sistema; uso paquetes de Docker de '${CODENAME}'"
    elif [ "$CODENAME" != "$BASE" ]; then
      aviso "Docker no publica aún para '${BASE}'; uso paquetes de '${CODENAME}'"
    fi
    sudo curl -fsSL "https://download.docker.com/linux/${FAMILIA}/gpg" -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${FAMILIA} ${CODENAME} stable" |
      sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    REPOS_NUEVOS=1
    ok "repo de Docker (${FAMILIA} ${CODENAME})"
  fi
fi
if ! command -v ddev >/dev/null 2>&1; then
  INSTALAR_DDEV=1
  curl -fsSL https://pkg.ddev.com/apt/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/ddev.gpg >/dev/null
  sudo chmod a+r /etc/apt/keyrings/ddev.gpg
  echo "deb [signed-by=/etc/apt/keyrings/ddev.gpg] https://pkg.ddev.com/apt/ * *" |
    sudo tee /etc/apt/sources.list.d/ddev.list >/dev/null
  REPOS_NUEVOS=1
  ok "repo de DDEV"
fi
if [ "$INSTALL_IDES" = 1 ] && ! command -v code >/dev/null 2>&1; then
  INSTALAR_CODE=1
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |
    sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  REPOS_NUEVOS=1
  ok "repo de VS Code"
fi
if [ "$REPOS_NUEVOS" = 1 ]; then apt_get update -y; else ok "nada nuevo que registrar"; fi

# ------------------------------------------------------------------ docker
if [ "$INSTALL_DOCKER" = 1 ]; then
  paso "Docker Engine"
  if [ "$INSTALAR_DOCKER_CE" = 1 ]; then
    apt_get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi
  if [ -d /run/systemd/system ]; then
    sudo systemctl enable --now docker
  else
    # derivados sin systemd (MX Linux, antiX, Devuan): el paquete trae también un script de init clásico
    sudo update-rc.d docker defaults >/dev/null 2>&1 || true
    sudo service docker status >/dev/null 2>&1 || sudo service docker start
  fi
  if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    NECESITA_RELOGIN=1
  fi
  ok "docker listo"
fi

# ------------------------------------------------------------------ ddev
paso "DDEV"
if [ "$INSTALAR_DDEV" = 1 ]; then apt_get install -y ddev; fi
# sin telemetría ni preguntas la primera vez
ddev config global --instrumentation-opt-in=false >/dev/null 2>&1 || true
ok "ddev listo: $(ddev --version)"

# ------------------------------------------------------------------ mkcert
paso "mkcert (SSL local confiable para *.ddev.site)"
if ! command -v mkcert >/dev/null 2>&1; then
  if ! apt_get install -y mkcert; then
    aviso "mkcert no está en apt; descargo el binario oficial"
    MK_ARCH=$ARCH
    if [ "$ARCH" = armhf ]; then MK_ARCH=arm; fi # así nombra mkcert su binario de 32 bits
    MK_URL=$(curl -fsSL https://api.github.com/repos/FiloSottile/mkcert/releases/latest |
      jq -r --arg a "linux-${MK_ARCH}" '.assets[] | select(.name | endswith($a)) | .browser_download_url' || true)
    if [ -z "$MK_URL" ]; then
      fallo "No pude obtener la URL de mkcert (¿límite de la API de GitHub?). Instálalo a mano: https://github.com/FiloSottile/mkcert"
    fi
    sudo curl -fsSL "$MK_URL" -o /usr/local/bin/mkcert
    sudo chmod +x /usr/local/bin/mkcert
  fi
fi
mkcert -install
ok "CA local instalada; los navegadores confiarán en https://*.ddev.site"

# ------------------------------------------------------------------ node
instalar_node_nvm

# ------------------------------------------------------------------ php nativo
if [ "$INSTALL_NATIVE_PHP" = "1" ]; then
  paso "PHP CLI + Composer nativos (conveniencia; las versiones por proyecto viven en DDEV)"
  apt_get install -y php-cli php-curl php-mbstring php-xml php-zip php-intl \
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
    apt_get install -y gh || aviso "gh no disponible en apt; instálalo desde https://cli.github.com"
  fi
fi

# ------------------------------------------------------------------ IDEs
if [ "$INSTALL_IDES" = "1" ]; then
  paso "IDEs"
  if [ "$INSTALAR_CODE" = 1 ]; then
    apt_get install -y code
    ok "VS Code instalado"
  else
    ok "VS Code ya instalado"
  fi
  if command -v phpstorm >/dev/null 2>&1 || [ -d "$HOME/.local/share/JetBrains" ]; then
    ok "PhpStorm / JetBrains Toolbox detectado"
  else
    aviso "PhpStorm no detectado: instálalo con JetBrains Toolbox → https://www.jetbrains.com/toolbox-app/"
  fi
fi
if [ "$INSTALL_VSCODE_EXTS" = "1" ] && command -v code >/dev/null 2>&1; then
  instalar_extensiones_vscode "$(command -v code)"
fi

# ------------------------------------------------------------------ sistema
paso "Ajustes de sistema para desarrollo"
sudo install -m 0755 -d /etc/sysctl.d # las imágenes mínimas de Debian no lo traen
echo 'fs.inotify.max_user_watches=524288' | sudo tee /etc/sysctl.d/60-dev-inotify.conf >/dev/null
if sudo sysctl --system >/dev/null 2>&1; then
  ok "inotify ampliado (watchers para Vite/HMR en proyectos grandes)"
else
  aviso "No pude aplicar sysctl ahora (¿contenedor, o sin permisos?); queda configurado para el próximo arranque"
fi

# ------------------------------------------------------------------ git + helpers
revisar_git
RC="$HOME/.bashrc"
case "${SHELL:-}" in */zsh) RC="$HOME/.zshrc" ;; esac # Kali y otros derivados traen zsh por defecto
instalar_helpers "$RAIZ_REPO" "$RC"

# ------------------------------------------------------------------ resumen
paso "¡Máquina lista!"
INSTALADO="ddev, mkcert (CA local), node/npm (nvm)"
if [ "$INSTALL_DOCKER" = 1 ]; then INSTALADO="docker, $INSTALADO"; fi
if [ "$INSTALL_NATIVE_PHP" = 1 ]; then INSTALADO="$INSTALADO, php+composer"; fi
if [ "$INSTALL_GH" = 1 ]; then INSTALADO="$INSTALADO, gh"; fi
cat <<RESUMEN

  Instalado: ${INSTALADO}

  Crear proyecto Laravel nuevo:      new-laravel <nombre> [php] [node] [mysql]
  Adoptar proyecto existente:        cd proyecto && adopt-laravel
  Respaldar todo antes de formatear: backup-projects   (y después: restore-projects)
  Revisar que todo esté en orden:    kit-doctor

  Guía completa: ${RAIZ_REPO}/README.md
  Log de esta corrida: ${KIT_LOG}

RESUMEN
if [ "$NECESITA_RELOGIN" = "1" ]; then
  aviso "IMPORTANTE: cierra sesión y vuelve a entrar (o reinicia) para usar docker sin sudo."
fi
