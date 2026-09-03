#!/usr/bin/env bash
# lib/comun.sh — lo que comparten instaladores y helpers: mensajes, log, chequeos,
# edición de .env y utilidades de DDEV.
#
# Se carga así (RAIZ = carpeta del kit):   . "$RAIZ/lib/comun.sh"
# Compatible con el bash 3.2 de macOS y con `set -euo pipefail`. Solo define
# funciones y variables: no ejecuta nada al cargarse.

# ------------------------------------------------------------------ mensajes
# Colores solo si la salida es una terminal y nadie pidió NO_COLOR (no-color.org).
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  AZUL='\033[1;34m' VERDE='\033[1;32m' AMARILLO='\033[1;33m' ROJO='\033[1;31m' SC='\033[0m'
else
  AZUL='' VERDE='' AMARILLO='' ROJO='' SC=''
fi
PASO_ACTUAL=""
paso() {
  PASO_ACTUAL="$*"
  printf "\n${AZUL}==> %s${SC}\n" "$*"
}
ok() { printf "${VERDE}    ✔ %s${SC}\n" "$*"; }
aviso() { printf "${AMARILLO}    ⚠ %s${SC}\n" "$*"; }
fallo() {
  printf "${ROJO}✖ %s${SC}\n" "$*" >&2
  exit 1
}

# ------------------------------------------------------------------ ayuda
# Cada script documenta su uso en el comentario de cabecera; --help lo imprime.
mostrar_ayuda() { # mostrar_ayuda "$0"
  sed -n '2,/^[^#]/p' "$1" | grep '^#' | sed 's/^# \{0,1\}//'
}

# ------------------------------------------------------------------ log y errores
# Todo lo que se imprime queda también en ~/.laravel-ddev-kit/<nombre>-<fecha>.log,
# sin códigos de color: cuando algo falla, ese archivo es lo que hay que mirar o pegar.
KIT_LOG=""
kit_log_iniciar() { # kit_log_iniciar setup-debian
  local dir=${KIT_LOG_DIR:-$HOME/.laravel-ddev-kit}
  mkdir -p "$dir"
  KIT_LOG="$dir/$1-$(date +%Y%m%d-%H%M%S).log"
  exec > >(tee >(sed $'s/\033\\[[0-9;]*m//g' >>"$KIT_LOG")) 2>&1
}
# Con `set -e` un fallo corta el script sin decir nada. Este trap dice en qué paso
# fue, qué comando, y dónde está el log:
#   trap 'kit_trap_error $LINENO "$BASH_COMMAND"' ERR
kit_trap_error() {
  echo
  printf "${ROJO}✖ Falló en «%s» (línea %s): %s${SC}\n" "${PASO_ACTUAL:-inicio}" "$1" "$2" >&2
  if [ -n "$KIT_LOG" ]; then echo "  Log completo: $KIT_LOG" >&2; fi
  echo "  El instalador es idempotente: corrige la causa y vuelve a correrlo; salta lo ya hecho." >&2
}

# ------------------------------------------------------------------ chequeos
requiere() { # requiere ddev docker jq
  local h
  for h in "$@"; do
    command -v "$h" >/dev/null 2>&1 || fallo "Falta '$h'. Corre primero el instalador del kit: bash setup.sh"
  done
}
docker_responde() {
  docker info >/dev/null 2>&1 || fallo "Docker no responde. Linux: 'sudo systemctl start docker' (si acabas de instalar, cierra sesión y vuelve a entrar). macOS: abre Docker Desktop u OrbStack, o 'colima start'."
}
# DDEV usa el nombre de proyecto como hostname (https://<nombre>.ddev.site): letras,
# dígitos y guiones, sin guion al inicio ni al final.
# En locale C: en es_ES/en_US.UTF-8 el rango a-z acepta letras acentuadas.
nombre_valido() { (
  LC_ALL=C
  export LC_ALL
  [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]]
); }
sugerir_nombre() {
  printf '%s' "$1" | LC_ALL=C tr 'A-Z_. ' 'a-z---' | LC_ALL=C tr -cd 'a-z0-9-' | sed -E 's/^-+//; s/-+$//; s/-{2,}/-/g'
}

# ------------------------------------------------------------------ .env
# Cambia (o agrega) CLAVE=valor tocando solo la PRIMERA coincidencia: las variantes
# comentadas de referencia se respetan y, si la clave solo existe comentada, se
# descomenta. Sin sed -i (GNU y BSD difieren) y el valor viaja por ENVIRON para
# que awk no interprete barras invertidas.
env_set() { # env_set CLAVE valor [archivo=.env]
  local clave=$1 valor=$2 archivo=${3:-.env}
  if [ ! -f "$archivo" ]; then : >"$archivo"; fi
  if grep -qE "^${clave}=" "$archivo"; then
    K="$clave" V="$valor" awk '!hecho && index($0, ENVIRON["K"] "=") == 1 { print ENVIRON["K"] "=" ENVIRON["V"]; hecho=1; next } { print }' \
      "$archivo" >"$archivo.tmp" && mv "$archivo.tmp" "$archivo"
  elif grep -qE "^#[[:space:]]*${clave}=" "$archivo"; then
    K="$clave" V="$valor" awk '!hecho && $0 ~ "^#[[:space:]]*" ENVIRON["K"] "=" { print ENVIRON["K"] "=" ENVIRON["V"]; hecho=1; next } { print }' \
      "$archivo" >"$archivo.tmp" && mv "$archivo.tmp" "$archivo"
  else
    printf '%s=%s\n' "$clave" "$valor" >>"$archivo"
  fi
}

# ------------------------------------------------------------------ ddev
# Un campo de `ddev describe -j` (primary_url, mailpit_https_url…) o el valor por
# defecto si DDEV no responde. La URL real puede llevar puerto: si 80/443 están
# ocupados (p. ej. por Laravel Valet) el router cae a puertos alternativos.
ddev_url() { # ddev_url primary_url https://x.ddev.site
  local v
  v=$(ddev describe -j 2>/dev/null | jq -r ".raw.$1 // empty" || true)
  printf '%s' "${v:-$2}"
}
