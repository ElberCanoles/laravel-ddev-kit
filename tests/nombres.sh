#!/usr/bin/env bash
# nombre_valido y sugerir_nombre (lib/comun.sh): reglas de hostname de DDEV.
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
# shellcheck source=../lib/comun.sh
. "$RAIZ/lib/comun.sh"

echo "válidos"
for n in mi-app MiApp app2 a a-b-c 123; do
  caso "'$n' es válido"
  if nombre_valido "$n"; then pasa; else falla; fi
done
echo "inválidos"
for n in Mi_App -foo foo- foo.bar 'mi tienda' '' 'ñandu' 'a--' 'app/2'; do
  caso "'$n' se rechaza"
  if nombre_valido "$n"; then falla; else pasa; fi
done
echo "sugerencias"
caso "Mi_App → mi-app"
assert_eq "$(sugerir_nombre 'Mi_App')" "mi-app"
caso "foo.bar → foo-bar"
assert_eq "$(sugerir_nombre 'foo.bar')" "foo-bar"
caso "'mi  tienda web' → mi-tienda-web"
assert_eq "$(sugerir_nombre 'mi  tienda web')" "mi-tienda-web"
caso "-foo- → foo"
assert_eq "$(sugerir_nombre '-foo-')" "foo"
caso "la sugerencia siempre es válida"
if nombre_valido "$(sugerir_nombre '__Proyecto Ñ 2026!!')"; then pasa; else falla "$(sugerir_nombre '__Proyecto Ñ 2026!!')"; fi

resumen
