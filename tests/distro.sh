#!/usr/bin/env bash
# Detección de familia Debian y del codename para el repo de Docker (lib/distro.sh),
# con os-release y debian_version falsos y un download.docker.com simulado.
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
# shellcheck source=../lib/comun.sh
. "$RAIZ/lib/comun.sh"
# shellcheck source=../lib/distro.sh
. "$RAIZ/lib/distro.sh"

# lo que publicaba download.docker.com el 2026-09-01
docker_publica() {
  case "$1/$2" in
    ubuntu/jammy | ubuntu/noble | ubuntu/plucky | ubuntu/questing | ubuntu/resolute) return 0 ;;
    debian/bullseye | debian/bookworm | debian/trixie) return 0 ;;
    *) return 1 ;;
  esac
}

# escenario <os-release con \n> <debian_version o -> [DOCKER_CODENAME]  → "familia base codename" | "rechazado"
escenario() {
  printf '%b' "$1" >"$TMP/os-release"
  rm -f "$TMP/debian_version"
  if [ "$2" != "-" ]; then printf '%s\n' "$2" >"$TMP/debian_version"; fi
  if ! detectar_familia_debian "$TMP/os-release" "$TMP/debian_version"; then
    echo "rechazado"
    return 0
  fi
  local base codename
  base=$(codename_base "$FAMILIA" "$TMP/debian_version")
  codename=$(elegir_codename_docker "$FAMILIA" "$base" "${VERSION_CODENAME:-}" "${3:-}" || echo "-")
  echo "$FAMILIA ${base:--} $codename"
}

echo "familia Ubuntu"
caso "Ubuntu 26.04 (resolute)"
assert_eq "$(escenario 'ID=ubuntu\nID_LIKE=debian\nVERSION_CODENAME=resolute\nUBUNTU_CODENAME=resolute\n' 'forky/sid')" "ubuntu resolute resolute"
caso "Ubuntu 24.04 (noble)"
assert_eq "$(escenario 'ID=ubuntu\nID_LIKE=debian\nVERSION_CODENAME=noble\nUBUNTU_CODENAME=noble\n' 'trixie/sid')" "ubuntu noble noble"
caso "Ubuntu futuro sin paquetes de Docker cae a noble"
assert_eq "$(escenario 'ID=ubuntu\nID_LIKE=debian\nVERSION_CODENAME=zany\nUBUNTU_CODENAME=zany\n' 'forky/sid')" "ubuntu zany noble"
caso "Linux Mint 22 usa su base noble, no 'wilma'"
assert_eq "$(escenario 'ID=linuxmint\nID_LIKE="ubuntu debian"\nVERSION_CODENAME=wilma\nUBUNTU_CODENAME=noble\n' 'trixie/sid')" "ubuntu noble noble"
caso "Pop!_OS 22.04"
assert_eq "$(escenario 'ID=pop\nID_LIKE="ubuntu debian"\nVERSION_CODENAME=jammy\nUBUNTU_CODENAME=jammy\n' 'bookworm/sid')" "ubuntu jammy jammy"
caso "elementary OS 8 (ID_LIKE solo ubuntu)"
assert_eq "$(escenario 'ID=elementary\nID_LIKE=ubuntu\nVERSION_CODENAME=circe\nUBUNTU_CODENAME=noble\n' 'trixie/sid')" "ubuntu noble noble"
caso "DOCKER_CODENAME forzado gana"
assert_eq "$(escenario 'ID=ubuntu\nID_LIKE=debian\nVERSION_CODENAME=resolute\nUBUNTU_CODENAME=resolute\n' 'forky/sid' jammy)" "ubuntu resolute jammy"

echo "familia Debian"
caso "Debian 13 (trixie)"
assert_eq "$(escenario 'ID=debian\nVERSION_CODENAME=trixie\n' '13.1')" "debian trixie trixie"
caso "Debian 12 (bookworm)"
assert_eq "$(escenario 'ID=debian\nVERSION_CODENAME=bookworm\n' '12.11')" "debian bookworm bookworm"
caso "Debian sid sin VERSION_CODENAME deduce forky y cae a trixie"
assert_eq "$(escenario 'ID=debian\n' 'forky/sid')" "debian forky trixie"
caso "LMDE 6 declara DEBIAN_CODENAME"
assert_eq "$(escenario 'ID=linuxmint\nID_LIKE=debian\nVERSION_CODENAME=faye\nDEBIAN_CODENAME=bookworm\n' '12.5')" "debian bookworm bookworm"
caso "Kali rolling (base testing) cae a trixie"
assert_eq "$(escenario 'ID=kali\nID_LIKE=debian\nVERSION_CODENAME=kali-rolling\n' 'forky/sid')" "debian forky trixie"
caso "MX Linux 23 deduce bookworm de /etc/debian_version"
assert_eq "$(escenario 'ID=mx\nID_LIKE=debian\n' '12.5')" "debian bookworm bookworm"
caso "Raspberry Pi OS 64 bits"
assert_eq "$(escenario 'ID=debian\nVERSION_CODENAME=bookworm\n' '12.11')" "debian bookworm bookworm"
caso "Devuan daedalus deduce bookworm"
assert_eq "$(escenario 'ID=devuan\nID_LIKE=debian\nVERSION_CODENAME=daedalus\n' '12.2')" "debian bookworm bookworm"
if command -v apt-get >/dev/null 2>&1; then
  caso "derivado sin ID_LIKE pero con apt y /etc/debian_version"
  assert_eq "$(escenario 'ID=raro\n' '12.1')" "debian bookworm bookworm"
fi

echo "otras familias"
caso "Fedora se rechaza"
assert_eq "$(escenario 'ID=fedora\nPRETTY_NAME="Fedora 42"\n' '-')" "rechazado"
caso "Arch se rechaza"
assert_eq "$(escenario 'ID=arch\n' '-')" "rechazado"
caso "os-release inexistente se rechaza"
rm -f "$TMP/os-release" "$TMP/debian_version"
if detectar_familia_debian "$TMP/os-release" "$TMP/debian_version"; then falla "aceptó"; else pasa; fi

resumen
