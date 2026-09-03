#!/usr/bin/env bash
# tests/run.sh — corre todas las pruebas, o solo algunas: bash tests/run.sh vite env_set
# No tocan tu sistema: usan ddev y docker simulados.
set -u
cd -- "$(dirname -- "$0")/.." || exit 1
archivos=()
if [ $# -gt 0 ]; then
  for a in "$@"; do archivos+=("tests/$a.sh"); done
else
  for a in tests/*.sh; do archivos+=("$a"); done
fi
total=0
fallidos=()
for t in "${archivos[@]}"; do
  case "$t" in tests/run.sh | tests/lib.sh) continue ;; esac
  total=$((total + 1))
  echo "== $t"
  if ! bash "$t"; then fallidos+=("$t"); fi
  echo
done
if [ "${#fallidos[@]}" -gt 0 ]; then
  echo "✖ ${#fallidos[@]} de $total archivos con fallas: ${fallidos[*]}"
  exit 1
fi
echo "✔ $total archivos de pruebas ok"
