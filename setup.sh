#!/usr/bin/env bash
#
# setup.sh — Punto de entrada del kit: detecta tu sistema operativo y corre
# el instalador que corresponde.
#
#   Linux (Debian, Ubuntu y derivados) → setup-debian.sh
#   macOS                              → setup-macos.sh
#
# Uso:
#   bash setup.sh
#   bash setup.sh --help    (muestra la ayuda del instalador de tu sistema)
#
# Los toggles (INSTALL_GH=0, DOCKER_PROVIDER=..., etc.) están documentados en
# la cabecera de cada instalador y se pasan igual: INSTALL_GH=0 bash setup.sh
set -euo pipefail

AQUI=$(cd -- "$(dirname -- "$0")" && pwd)

case "$(uname -s)" in
  Darwin) exec bash "$AQUI/setup-macos.sh" "$@" ;;
  Linux) exec bash "$AQUI/setup-debian.sh" "$@" ;;
  *)
    echo "Sistema no soportado: $(uname -s). Hay instaladores para Linux (familia Debian) y macOS."
    exit 1
    ;;
esac
