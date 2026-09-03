#!/usr/bin/env bash
# new-laravel de principio a fin con ddev y docker simulados: crea la carpeta, configura
# DDEV con las versiones pedidas, instala MinIO, deja .env, vite.config, launch.json y
# el commit inicial. También --kit/--db y los chequeos previos (nombre, carpeta).
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

mkdir -p "$TMP/bin" "$TMP/work" "$TMP/home"
# HOME limpio: que el gitconfig del usuario (firmas, hooks…) no cambie el resultado
export HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP/bin/docker"
# El ddev falso registra cada llamada y simula lo justo: config escribe .ddev/config.yaml,
# composer create-project deja un esqueleto de Laravel, describe da las URLs (con un
# project_tld distinto y puerto alternativo del router, para comprobar que las URLs
# salen de ahí) y exec node usa el node local, si hay, sobre el vite.config
cat >"$TMP/bin/ddev" <<FAKE
#!/usr/bin/env bash
echo "\$*" >>"$TMP/llamadas"
case "\$1" in
  config) mkdir -p .ddev && printf 'name: %s\ntype: laravel\n' "\$(basename "\$PWD")" >.ddev/config.yaml ;;
  describe) n=\$(basename "\$PWD"); printf '{"raw":{"primary_url":"https://%s.ddev.local:33001","mailpit_https_url":"https://%s.ddev.local:33026","status":"running"}}\n' "\$n" "\$n" ;;
  composer)
    if [ "\$2" = create-project ]; then
      echo "#!/usr/bin/env php" >artisan
      mkdir -p config database
      echo "return ['connections' => ['mysql' => [], 'mariadb' => []]];" >config/database.php
      printf 'APP_NAME=Laravel\nAPP_URL=http://localhost\nDB_CONNECTION=sqlite\n# DB_HOST=127.0.0.1\n# DB_PORT=3306\n' >.env
      touch database/database.sqlite
      cp "$RAIZ/tests/fixtures/vite/laravel-13-skeleton.vite.config.js" vite.config.js
      echo '{"type":"module"}' >package.json
    fi ;;
  exec)
    shift
    [ "\$1" = node ] || exit 0
    command -v node >/dev/null 2>&1 || exit 0
    args=(); for a in "\$@"; do args+=("\${a#/var/www/html/}"); done
    "\${args[@]}" ;;
  *) exit 0 ;;
esac
FAKE
chmod +x "$TMP/bin/"*

echo "camino feliz"
SALIDA=$(cd "$TMP/work" && PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/new-laravel" tienda 2>&1)
CODIGO=$?
P="$TMP/work/tienda"
caso "termina bien"
assert_codigo "$CODIGO" 0
caso "ddev config con los valores por defecto (PHP 8.5, Node 24, MySQL 8.4)"
assert_contiene "$(cat "$TMP/llamadas")" "config --project-type=laravel --docroot=public --php-version=8.5 --nodejs-version=24 --database=mysql:8.4"
caso "instala MinIO, crea el proyecto sin preguntas, arranca, npm, migra y reinicia"
assert_eq "$(grep -cE '^(add-on get ddev/ddev-minio|composer create-project --no-interaction laravel/laravel|start -y|npm install|artisan migrate --no-interaction|restart -y)$' "$TMP/llamadas")" 6
caso "requiere el driver S3 y crea el bucket con el nombre del proyecto"
assert_eq "$(grep -cE '^(composer require --no-interaction league/flysystem-aws-s3-v3|mc mb --ignore-existing minio/tienda)' "$TMP/llamadas")" 2
caso "deja .ddev/config.kit.yaml"
if [ -f "$P/.ddev/config.kit.yaml" ]; then pasa; else falla; fi
caso ".env: APP_URL real de ddev describe, BD y Mailpit de DDEV"
assert_eq "$(grep -E '^(APP_URL|DB_CONNECTION|DB_HOST|DB_PORT|MAIL_HOST)=' "$P/.env" | sort | tr '\n' ' ')" "APP_URL=https://tienda.ddev.local:33001 DB_CONNECTION=mysql DB_HOST=db DB_PORT=3306 MAIL_HOST=127.0.0.1 "
caso ".env: MinIO con el bucket del proyecto y la URL pública sin el puerto del router"
assert_eq "$(grep -E '^(AWS_BUCKET|AWS_ENDPOINT|AWS_URL)=' "$P/.env" | sort | tr '\n' ' ')" "AWS_BUCKET=tienda AWS_ENDPOINT=http://minio:10101 AWS_URL=https://tienda.ddev.local:10101/tienda "
caso "vite.config.js configurado para DDEV"
assert_eq "$(grep -c 'DDEV_PRIMARY_URL_WITHOUT_PORT ?' "$P/vite.config.js")" 1
caso "launch.json de Xdebug, y el sqlite temporal del esqueleto borrado"
assert_eq "$([ -f "$P/.vscode/launch.json" ] && echo si)-$([ -e "$P/database/database.sqlite" ] || echo borrado)" "si-borrado"
caso "commit inicial en la rama main"
assert_eq "$(git -C "$P" branch --show-current)-$(git -C "$P" rev-list --count HEAD)" "main-1"
caso "el resumen muestra la app y la consola de MinIO con las URLs reales"
assert_eq "$(printf '%s' "$SALIDA" | grep -cE 'App: +https://tienda.ddev.local:33001|MinIO consola: +https://tienda.ddev.local:9090')" 2

echo "--kit, --db y chequeos previos"
rm -f "$TMP/llamadas"
SALIDA=$(cd "$TMP/work" && PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/new-laravel" panel --kit vue --php 8.4 --node 22 --db postgres 2>&1)
caso "--kit vue: paquete laravel/vue-starter-kit con las versiones pedidas"
assert_eq "$(grep -c 'composer create-project --no-interaction laravel/vue-starter-kit' "$TMP/llamadas")-$(grep -c 'php-version=8.4 --nodejs-version=22 --database=postgres:18' "$TMP/llamadas")" "1-1"
caso "--db postgres: .env con pgsql y 5432, y el resumen recuerda ddev psql"
assert_eq "$(grep -E '^DB_(CONNECTION|PORT)=' "$TMP/work/panel/.env" | tr '\n' ' ')|$(printf '%s' "$SALIDA" | grep -c 'ddev psql')" "DB_CONNECTION=pgsql DB_PORT=5432 |1"
SALIDA=$(cd "$TMP/work" && PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/new-laravel" tienda 2>&1)
CODIGO=$?
caso "carpeta ya existente: falla antes de tocar nada"
assert_eq "$CODIGO|$(printf '%s' "$SALIDA" | grep -c 'ya existe aquí')" "1|1"
SALIDA=$(cd "$TMP/work" && PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/new-laravel" 'Mi Tienda' 2>&1)
caso "nombre inválido: lo rechaza y sugiere uno válido"
assert_contiene "$SALIDA" "(p. ej. 'mi-tienda')"

resumen
