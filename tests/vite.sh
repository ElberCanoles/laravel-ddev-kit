#!/usr/bin/env bash
# configurar_vite (lib/laravel.sh) contra los vite.config reales de Laravel y los
# starter kits, más casos límite. 'ddev exec node' se simula con el node local.
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
# shellcheck source=../lib/comun.sh
. "$RAIZ/lib/comun.sh"
# shellcheck source=../lib/laravel.sh
. "$RAIZ/lib/laravel.sh"

HAY_NODE=0
if command -v node >/dev/null 2>&1; then HAY_NODE=1; fi
ddev() { # ddev exec node --check /var/www/html/<archivo>  → node local sobre el archivo relativo
  [ "$1" = exec ] || return 1
  shift
  [ "$HAY_NODE" = 1 ] || return 0
  local a args=()
  for a in "$@"; do args+=("${a#/var/www/html/}"); done
  "${args[@]}"
}
FIX="$RAIZ/tests/fixtures/vite"

# prueba <carpeta> <fixture|-> <nombre destino>  → deja SALIDA, RESULTADO, RESTOS y DIR
prueba() {
  DIR="$TMP/$1"
  mkdir -p "$DIR"
  echo '{"type":"module"}' >"$DIR/package.json"
  if [ "$2" != "-" ]; then cp "$FIX/$2" "$DIR/$3"; fi
  SALIDA=$(cd "$DIR" && configurar_vite 2>&1)
  RESULTADO=$(cat "$DIR/$3" 2>/dev/null || true)
  RESTOS=$(find "$DIR" -name '*.kit-tmp.*' | wc -l | tr -d ' ')
}
bloques_server() { printf '%s\n' "$RESULTADO" | grep -cE '^ *server *: *\{' || true; }
spreads() { printf '%s\n' "$RESULTADO" | grep -c 'DDEV_PRIMARY_URL_WITHOUT_PORT ?' || true; }
linea_de() { printf '%s\n' "$RESULTADO" | grep -n -- "$1" | head -1 | cut -d: -f1; }
node_check() { # solo si hay node
  if [ "$HAY_NODE" = 1 ]; then
    caso "$1: node --check"
    (cd "$DIR" && node --check "$2" 2>/dev/null)
    assert_codigo $? 0
  fi
}

echo "fusionar dentro del bloque server existente"
prueba esqueleto laravel-13-skeleton.vite.config.js vite.config.js
caso "esqueleto Laravel 13: un solo bloque server"
assert_eq "$(bloques_server)" 1
caso "esqueleto Laravel 13: spread de DDEV insertado"
assert_eq "$(spreads)" 1
caso "esqueleto Laravel 13: conserva watch.ignored"
assert_contiene "$RESULTADO" "storage/framework/views"
caso "esqueleto Laravel 13: el spread queda antes que watch"
if [ "$(linea_de 'DDEV_PRIMARY_URL_WITHOUT_PORT ?')" -lt "$(linea_de 'watch:')" ]; then pasa; else falla; fi
caso "esqueleto Laravel 13: sin archivos temporales"
assert_eq "$RESTOS" 0
node_check "esqueleto Laravel 13" vite.config.js

prueba vue vue-starter-kit.vite.config.ts vite.config.ts
caso "vue-starter-kit (TypeScript): un solo bloque server con spread"
assert_eq "$(bloques_server)-$(spreads)" "1-1"
prueba react react-starter-kit.vite.config.ts vite.config.ts
caso "react-starter-kit (TypeScript): un solo bloque server con spread"
assert_eq "$(bloques_server)-$(spreads)" "1-1"
prueba livewire livewire-starter-kit.vite.config.js vite.config.js
caso "livewire-starter-kit: un solo bloque server con spread"
assert_eq "$(bloques_server)-$(spreads)" "1-1"
caso "livewire-starter-kit: su 'cors: true' queda después y gana"
if [ "$(linea_de 'DDEV_PRIMARY_URL_WITHOUT_PORT ?')" -lt "$(linea_de 'cors: true')" ]; then pasa; else falla; fi
node_check "livewire-starter-kit" vite.config.js

echo "crear el bloque cuando no existe"
mkdir -p "$TMP/sinserver"
printf "import { defineConfig } from 'vite';\nexport default defineConfig({\n    plugins: [],\n});\n" >"$TMP/sinserver.js"
cp "$TMP/sinserver.js" "$TMP/sinserver/vite.config.js"
prueba sinserver - vite.config.js
caso "sin bloque server: lo crea con el spread"
assert_eq "$(bloques_server)-$(spreads)" "1-1"
node_check "sin bloque server" vite.config.js
caso "vite.config.mjs también se reconoce"
mkdir -p "$TMP/mjs" && cp "$TMP/sinserver.js" "$TMP/mjs/vite.config.mjs"
prueba mjs - vite.config.mjs
assert_eq "$(spreads)" 1

echo "no tocar lo que no corresponde"
mkdir -p "$TMP/conhost"
printf "import { defineConfig } from 'vite';\nexport default defineConfig({\n    server: {\n        host: 'localhost',\n    },\n});\n" >"$TMP/conhost/vite.config.js"
ORIGINAL=$(cat "$TMP/conhost/vite.config.js")
prueba conhost - vite.config.js
caso "con host propio: avisa y deja el archivo igual"
assert_contiene "$SALIDA" "configuración propia"
caso "con host propio: contenido intacto"
assert_eq "$RESULTADO" "$ORIGINAL"
mkdir -p "$TMP/raro"
printf "export default { plugins: [] };\n" >"$TMP/raro/vite.config.js"
prueba raro - vite.config.js
caso "estructura irreconocible: avisa"
assert_contiene "$SALIDA" "No reconocí"
caso "estructura irreconocible: sin spread"
assert_eq "$(spreads)" 0
mkdir -p "$TMP/hecho"
printf "export default { server: { origin: process.env.DDEV_PRIMARY_URL_WITHOUT_PORT } };\n" >"$TMP/hecho/vite.config.js"
prueba hecho - vite.config.js
caso "ya configurado: silencio y sin cambios"
assert_eq "$SALIDA" ""
prueba vacio - vite.config.js
caso "sin vite.config: avisa"
assert_contiene "$SALIDA" "No encontré"
if [ "$HAY_NODE" = 1 ]; then
  # el ancla está en un comentario: lo insertado cae fuera del objeto y solo lo detecta node
  mkdir -p "$TMP/comentado"
  printf "// export default defineConfig({\nexport default { plugins: [] };\n" >"$TMP/comentado/vite.config.js"
  ORIGINAL=$(cat "$TMP/comentado/vite.config.js")
  prueba comentado - vite.config.js
  caso "si aun así el resultado no es JS válido, avisa y conserva el original"
  assert_contiene "$SALIDA" "no pasó la comprobación"
  caso "si el resultado no es JS válido: contenido intacto y sin temporales"
  assert_eq "$RESULTADO|$RESTOS" "$ORIGINAL|0"
fi

echo "formatos que no vienen de prettier"
mkdir -p "$TMP/sinespacio"
printf "import { defineConfig } from 'vite';\nexport default defineConfig({\n    plugins: [],\n    server:{\n        watch: { ignored: ['x'] },\n    },\n});\n" >"$TMP/sinespacio/vite.config.js"
prueba sinespacio - vite.config.js
caso "server:{ sin espacio: se fusiona, un solo bloque server (antes creaba otro)"
assert_eq "$(bloques_server)-$(spreads)" "1-1"
caso "server:{ sin espacio: el spread quedó dentro del bloque existente"
if [ "$(linea_de 'DDEV_PRIMARY_URL_WITHOUT_PORT ?')" -lt "$(linea_de 'watch:')" ]; then pasa; else falla; fi
node_check "server:{ sin espacio" vite.config.js
mkdir -p "$TMP/comentariofinal"
printf "import { defineConfig } from 'vite';\nexport default defineConfig({\n    server: { // opciones del dev server\n        cors: true,\n    },\n});\n" >"$TMP/comentariofinal/vite.config.js"
prueba comentariofinal - vite.config.js
caso "server: { con comentario al final de línea: se fusiona"
assert_eq "$(bloques_server)-$(spreads)" "1-1"
node_check "server con comentario" vite.config.js
mkdir -p "$TMP/serverlinea"
printf "import { defineConfig } from 'vite';\nexport default defineConfig({\n    server: { cors: true },\n});\n" >"$TMP/serverlinea/vite.config.js"
ORIGINAL=$(cat "$TMP/serverlinea/vite.config.js")
prueba serverlinea - vite.config.js
caso "server en una sola línea: avisa y deja el archivo intacto"
assert_eq "$(printf '%s' "$SALIDA" | grep -c 'formato que no reconozco')|$RESULTADO" "1|$ORIGINAL"
mkdir -p "$TMP/tsunalinea"
printf "import { defineConfig } from 'vite';\nexport default defineConfig({ plugins: [] });\n" >"$TMP/tsunalinea/vite.config.ts"
ORIGINAL=$(cat "$TMP/tsunalinea/vite.config.ts")
prueba tsunalinea - vite.config.ts
caso "vite.config.ts de una línea: avisa y deja el archivo intacto (antes lo rompía)"
assert_eq "$(printf '%s' "$SALIDA" | grep -c 'No reconocí')|$RESULTADO|$RESTOS" "1|$ORIGINAL|0"

resumen
