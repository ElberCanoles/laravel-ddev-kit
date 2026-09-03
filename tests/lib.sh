#!/usr/bin/env bash
# tests/lib.sh — mini framework de pruebas: casos, aserciones y resumen. Sin
# dependencias; lo cargan los demás archivos de tests/.
CASOS=0
FALLOS=0
caso() {
  CASOS=$((CASOS + 1))
  printf '  %-64s ' "$1"
}
pasa() { echo "ok"; }
falla() {
  FALLOS=$((FALLOS + 1))
  echo "FALLA${1:+ — $1}"
}
assert_eq() { # assert_eq <obtenido> <esperado>
  if [ "$1" = "$2" ]; then pasa; else falla "esperaba '$2', obtuve '$1'"; fi
}
assert_contiene() { # assert_contiene <texto> <fragmento>
  if printf '%s' "$1" | grep -qF -- "$2"; then pasa; else falla "no contiene '$2'"; fi
}
assert_no_contiene() { # assert_no_contiene <texto> <fragmento>
  if printf '%s' "$1" | grep -qF -- "$2"; then falla "contiene '$2'"; else pasa; fi
}
assert_codigo() { # assert_codigo <obtenido> <esperado>
  if [ "$1" -eq "$2" ]; then pasa; else falla "código $1, esperaba $2"; fi
}
resumen() {
  echo
  echo "  $((CASOS - FALLOS))/$CASOS ok"
  [ "$FALLOS" -eq 0 ]
}
TMP=$(mktemp -d "${TMPDIR:-/tmp}/kit-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
# shellcheck disable=SC2034 # la usan los archivos de pruebas que cargan este
RAIZ=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export NO_COLOR=1
# stdin conocido: los ddev falsos consumen stdin como el real, y ningún test debe
# quedarse esperando a la terminal (o a una tubería abierta) de quien los corre
exec </dev/null
