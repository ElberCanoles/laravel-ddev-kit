#!/usr/bin/env bash
# --help funciona en todos los scripts, antes de cualquier chequeo del sistema.
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

for s in setup-debian.sh setup-macos.sh bin/new-laravel bin/adopt-laravel bin/backup-projects bin/restore-projects bin/kit-doctor; do
  SALIDA=$(bash "$RAIZ/$s" --help 2>&1)
  CODIGO=$?
  caso "$s --help sale con 0"
  assert_codigo "$CODIGO" 0
  caso "$s --help muestra el uso"
  assert_contiene "$SALIDA" "Uso"
done
SALIDA=$(bash "$RAIZ/setup.sh" --help 2>&1)
caso "setup.sh --help llega al instalador de este sistema"
assert_contiene "$SALIDA" "Toggles"
SALIDA=$(bash "$RAIZ/bin/new-laravel" 2>&1)
CODIGO=$?
caso "new-laravel sin argumentos: uso y código 1"
assert_eq "$CODIGO-$(printf '%s' "$SALIDA" | grep -c 'Uso: new-laravel')" "1-1"

resumen
