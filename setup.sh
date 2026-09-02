#!/usr/bin/env bash
#
# setup.sh — Punto de entrada del kit: detecta tu sistema operativo y corre
# el instalador que corresponde.
#
#   Linux (Ubuntu) → setup-ubuntu.sh
#   macOS          → setup-macos.sh
#
# Uso:
#   bash setup.sh
#
# Los toggles (INSTALL_GH=0, DOCKER_PROVIDER=..., etc.) están documentados en
# la cabecera de cada instalador y se pasan igual: INSTALL_GH=0 bash setup.sh
set -euo pipefail

AQUI=$(cd -- "$(dirname -- "$0")" && pwd)

case "$(uname -s)" in
  Darwin) exec bash "$AQUI/setup-macos.sh"  "$@" ;;
  Linux)  exec bash "$AQUI/setup-ubuntu.sh" "$@" ;;
  *)
    echo "Sistema no soportado: $(uname -s). Hay instaladores para Ubuntu/Linux y macOS."
    exit 1
    ;;
esac
