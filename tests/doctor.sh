#!/usr/bin/env bash
# kit-doctor con herramientas simuladas: informa bien cuando todo responde, marca ✖ y
# sale con 1 cuando Docker no responde, y revisa un proyecto Laravel.
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

mkdir -p "$TMP/bin" "$TMP/caroot" "$TMP/vacio"
touch "$TMP/caroot/rootCA.pem"
cat >"$TMP/bin/docker" <<FAKE
#!/usr/bin/env bash
case "\$1" in
  --version) echo "Docker version 29.0.0, build fake" ;;
  info) [ "\${FAKE_DOCKER_CAIDO:-0}" = 1 ] && exit 1 || exit 0 ;;
  compose) exit 0 ;;
  ps) exit 0 ;;
esac
FAKE
cat >"$TMP/bin/ddev" <<'FAKE'
#!/usr/bin/env bash
case "$1" in
  --version) echo "ddev version v1.25.3" ;;
  list) echo '{"raw":[{"name":"a","status":"running"},{"name":"b","status":"stopped"}]}' ;;
  describe) echo '{"raw":{"status":"stopped","primary_url":"https://p.ddev.site"}}' ;;
esac
FAKE
cat >"$TMP/bin/mkcert" <<FAKE
#!/usr/bin/env bash
case "\$1" in --version) echo "v1.4.4" ;; -CAROOT) echo "$TMP/caroot" ;; esac
FAKE
chmod +x "$TMP/bin/"*

echo "todo responde"
SALIDA=$(cd "$TMP/vacio" && PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/kit-doctor" 2>&1)
caso "docker responde"
assert_contiene "$SALIDA" "✔ el daemon responde"
caso "ddev y mkcert con versión"
assert_eq "$(printf '%s' "$SALIDA" | grep -cE '✔ (ddev: ddev version v1.25.3|mkcert: v1.4.4)')" 2
caso "CA de mkcert"
assert_contiene "$SALIDA" "✔ CA de mkcert creada ($TMP/caroot)"
caso "cuenta los proyectos DDEV"
assert_contiene "$SALIDA" "proyectos DDEV registrados: 2 (corriendo: 1)"
caso "fuera de un proyecto no revisa proyecto"
assert_no_contiene "$SALIDA" "Este proyecto"

echo "docker caído"
SALIDA=$(cd "$TMP/vacio" && FAKE_DOCKER_CAIDO=1 PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/kit-doctor" 2>&1)
CODIGO=$?
caso "sale con código 1"
assert_codigo "$CODIGO" 1
caso "marca el daemon como problema con la solución"
assert_contiene "$SALIDA" "✖ el daemon no responde"
caso "resume los problemas"
assert_contiene "$SALIDA" "problema(s) que corregir"

echo "dentro de un proyecto"
mkdir -p "$TMP/proy/.ddev" "$TMP/proy/vendor"
cd "$TMP/proy" || exit 1
echo "#!/usr/bin/env php" >artisan
echo "name: proy" >.ddev/config.yaml
printf 'APP_KEY=\nDB_HOST=127.0.0.1\n' >.env
echo '{}' >composer.lock
echo '{}' >package-lock.json
printf 'export default { server: {} }\n' >vite.config.js
SALIDA=$(PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/kit-doctor" 2>&1)
caso "revisa el proyecto de la carpeta actual"
assert_contiene "$SALIDA" "Este proyecto (proy)"
caso "detecta APP_KEY vacía"
assert_contiene "$SALIDA" ".env sin APP_KEY"
caso "detecta DB_HOST que no es db"
assert_contiene "$SALIDA" ".env no apunta a DDEV"
caso "detecta vendor/ sin instalar"
assert_contiene "$SALIDA" "sin vendor/ → ddev composer install"
caso "detecta node_modules sin instalar"
assert_contiene "$SALIDA" "sin node_modules/ → ddev npm install"
caso "detecta vite.config sin DDEV"
assert_contiene "$SALIDA" "vite.config sin la configuración de DDEV"
caso "detecta el proyecto detenido"
assert_contiene "$SALIDA" "proyecto stopped → ddev start"
touch vendor/autoload.php
sleep 1 && touch vendor/autoload.php
SALIDA=$(PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/kit-doctor" 2>&1)
caso "vendor/ al día cuando autoload es más nuevo que el lock"
assert_contiene "$SALIDA" "✔ vendor/ al día"

echo "ayuda"
SALIDA=$(bash "$RAIZ/bin/kit-doctor" --help 2>&1)
caso "--help imprime el uso"
assert_contiene "$SALIDA" "Uso: kit-doctor"

resumen
