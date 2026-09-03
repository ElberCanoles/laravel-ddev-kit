#!/usr/bin/env bash
# lib/distro.sh — qué Linux es este y qué repo de Docker le corresponde.
#
# Solo familia Debian: Debian, Ubuntu y sus derivados. Docker publica un repo para
# Debian y otro para Ubuntu, por versión (codename); un derivado (Linux Mint, LMDE,
# Kali…) tiene codename propio y hay que usar el de su base. Las funciones reciben
# rutas para poder probarse con archivos falsos (tests/distro.sh).

# Carga os-release y decide FAMILIA=ubuntu|debian. Devuelve 1 si no es familia Debian.
# Los derivados declaran su base en ID_LIKE (Mint → "ubuntu debian", LMDE o Kali → "debian").
# shellcheck disable=SC2034 # FAMILIA, PRETTY_NAME, etc. las usa el script que la llama
detectar_familia_debian() { # detectar_familia_debian [os-release] [debian_version]
  local os_release=${1:-/etc/os-release} debian_version=${2:-/etc/debian_version}
  ID="" ID_LIKE="" PRETTY_NAME="" VERSION_CODENAME="" UBUNTU_CODENAME="" DEBIAN_CODENAME=""
  # shellcheck disable=SC1090
  if [ -r "$os_release" ]; then . "$os_release"; fi
  case " ${ID:-} ${ID_LIKE:-} " in
    *" ubuntu "*) FAMILIA=ubuntu ;;
    *" debian "*) FAMILIA=debian ;;
    *)
      # derivado que no declara su base, pero es Debian por dentro
      if [ -f "$debian_version" ] && command -v apt-get >/dev/null 2>&1; then
        FAMILIA=debian
      else
        FAMILIA=""
        return 1
      fi
      ;;
  esac
}

# Codename de la distro BASE (puede quedar vacío si no se pudo deducir):
#   Ubuntu y derivados: UBUNTU_CODENAME (Mint, Pop!_OS y Zorin lo declaran).
#   Debian: VERSION_CODENAME; derivados: DEBIAN_CODENAME (LMDE) o /etc/debian_version,
#   que dice "12.x" en estable o "forky/sid" en testing (MX, Devuan, Kali…).
codename_base() { # codename_base <familia> [debian_version]  → imprime el codename
  local familia=$1 debian_version=${2:-/etc/debian_version} base="" dv
  if [ "$familia" = ubuntu ]; then
    base="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
  else
    base="${DEBIAN_CODENAME:-}"
    if [ -z "$base" ] && [ "${ID:-}" = debian ]; then base="${VERSION_CODENAME:-}"; fi
    if [ -z "$base" ] && [ -r "$debian_version" ]; then
      dv=$(cat "$debian_version")
      case "$dv" in
        11*) base=bullseye ;;
        12*) base=bookworm ;;
        13*) base=trixie ;;
        14*) base=forky ;;
        */sid) base=${dv%%/*} ;;
      esac
    fi
  fi
  printf '%s' "$base"
}

# ¿Publica Docker paquetes para ese codename? (las pruebas redefinen esta función)
docker_publica() { # docker_publica <familia> <codename>
  curl -fsSL --head "https://download.docker.com/linux/$1/dists/$2/Release" >/dev/null 2>&1
}

# Primer codename con paquetes, en este orden: el forzado por el usuario, el de la
# base, el propio de la distro y, como respaldo, las últimas estables de la familia.
elegir_codename_docker() { # elegir_codename_docker <familia> <base> <propio> <forzado>
  local familia=$1 base=$2 propio=$3 forzado=$4 cand respaldo
  if [ "$familia" = ubuntu ]; then respaldo="noble jammy"; else respaldo="trixie bookworm"; fi
  # shellcheck disable=SC2086
  for cand in "$forzado" "$base" "$propio" $respaldo; do
    if [ -z "$cand" ]; then continue; fi
    if docker_publica "$familia" "$cand"; then
      printf '%s' "$cand"
      return 0
    fi
  done
  return 1
}
