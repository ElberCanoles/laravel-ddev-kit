#!/usr/bin/env bash
# lib/laravel.sh: motores de BD, driver de Laravel, .env por motor, lectura de
# .ddev/config.yaml y la plantilla .ddev/config.kit.yaml. Más el parseo de opciones
# de new-laravel, que falla antes de tocar nada.
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
# shellcheck source=../lib/comun.sh
. "$RAIZ/lib/comun.sh"
# shellcheck source=../lib/laravel.sh
. "$RAIZ/lib/laravel.sh"

echo "normalizar_db"
caso "mysql → mysql:8.4"
assert_eq "$(normalizar_db mysql)" "mysql:8.4"
caso "mariadb → mariadb:11.8"
assert_eq "$(normalizar_db mariadb)" "mariadb:11.8"
caso "postgres → postgres:18"
assert_eq "$(normalizar_db postgres)" "postgres:18"
caso "alias pgsql y postgresql"
assert_eq "$(normalizar_db pgsql)-$(normalizar_db postgresql:17)" "postgres:18-postgres:17"
caso "versión explícita se respeta"
assert_eq "$(normalizar_db mysql:8.0)" "mysql:8.0"
caso "motor desconocido: falla"
if normalizar_db oracle >/dev/null; then falla; else pasa; fi

echo "driver_laravel"
cd "$TMP" || exit 1
mkdir -p config
caso "postgres → pgsql"
assert_eq "$(driver_laravel postgres)" "pgsql"
caso "mysql → mysql"
assert_eq "$(driver_laravel mysql)" "mysql"
echo "return ['connections' => ['mysql' => []]];" >config/database.php
caso "mariadb sin conexión mariadb en config/database.php → mysql"
assert_eq "$(driver_laravel mariadb)" "mysql"
echo "return ['connections' => ['mysql' => [], 'mariadb' => []]];" >config/database.php
caso "mariadb con conexión mariadb declarada → mariadb"
assert_eq "$(driver_laravel mariadb)" "mariadb"

echo "env_laravel_ddev por motor"
printf 'DB_CONNECTION=sqlite\nDB_PORT=3306\n' >.env
env_laravel_ddev https://a.ddev.site postgres:18
caso "postgres: DB_CONNECTION=pgsql y DB_PORT=5432"
assert_eq "$(grep -E '^DB_(CONNECTION|PORT)=' .env | tr '\n' ' ')" "DB_CONNECTION=pgsql DB_PORT=5432 "
env_laravel_ddev https://a.ddev.site
caso "sin motor: mysql y 3306"
assert_eq "$(grep -E '^DB_(CONNECTION|PORT)=' .env | tr '\n' ' ')" "DB_CONNECTION=mysql DB_PORT=3306 "
caso "APP_URL, DB_HOST y Mailpit"
assert_eq "$(grep -E '^(APP_URL|DB_HOST|MAIL_HOST|MAIL_PORT)=' .env | sort | tr '\n' ' ')" "APP_URL=https://a.ddev.site DB_HOST=db MAIL_HOST=127.0.0.1 MAIL_PORT=1025 "

echo "lectura de .ddev/config.yaml"
mkdir -p .ddev
printf 'name: x\nphp_version: "8.4"\nnodejs_version: "22"\ndatabase:\n    type: postgres\n    version: "17"\nwebserver_type: nginx-fpm\n' >.ddev/config.yaml
caso "formato de DDEV (4 espacios)"
assert_eq "$(ddev_php_configurado)-$(ddev_node_configurado)-$(ddev_db_configurada)" "8.4-22-postgres:17"
printf 'database:\n  type: mariadb\n  version: "11.8"\n' >.ddev/config.yaml
caso "también con 2 espacios; php y node ausentes quedan vacíos"
assert_eq "$(ddev_php_configurado)-$(ddev_node_configurado)-$(ddev_db_configurada)" "--mariadb:11.8"
rm -f .ddev/config.yaml
caso "sin config.yaml: vacío, sin error"
assert_eq "$(
  ddev_db_configurada
  echo "|$?"
)" "|0"

echo "ddev_config_kit"
ddev_config_kit "$RAIZ" && ddev_config_kit "$RAIZ"
caso "copia la plantilla una sola vez"
assert_eq "$(grep -c 'name: vite' .ddev/config.kit.yaml)" 1
caso "la plantilla trae Vite, colas, scheduler y corepack"
assert_eq "$(grep -cE '^(web_extra_exposed_ports|web_extra_daemons|corepack_enable):' .ddev/config.kit.yaml)-$(grep -c 'name: queue\|name: schedule' .ddev/config.kit.yaml)" "3-2"
echo "mio" >.ddev/config.kit.yaml
ddev_config_kit "$RAIZ"
caso "no pisa un config.kit.yaml editado por el usuario"
assert_eq "$(cat .ddev/config.kit.yaml)" "mio"

echo "adopt-laravel deduce el motor del .env.example (con ddev simulado)"
mkdir -p "$TMP/adopt/bin" "$TMP/adopt/proy"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP/adopt/bin/docker"
cat >"$TMP/adopt/bin/ddev" <<FAKE
#!/usr/bin/env bash
echo "\$*" >>"$TMP/adopt/llamadas"
case "\$1" in
  describe) printf '{"raw":{"primary_url":"https://proy.ddev.site","status":"running"}}\n' ;;
  config) mkdir -p .ddev && printf 'name: proy\ntype: laravel\n' >.ddev/config.yaml ;;
  *) exit 0 ;;
esac
FAKE
chmod +x "$TMP/adopt/bin/"*
(cd "$TMP/adopt/proy" && echo "#!/usr/bin/env php" >artisan && printf 'APP_KEY=\nDB_CONNECTION=pgsql\n' >.env.example)
SALIDA=$(cd "$TMP/adopt/proy" && PATH="$TMP/adopt/bin:$PATH" bash "$RAIZ/bin/adopt-laravel" 2>&1)
CODIGO=$?
caso "sin .env pero con .env.example: termina bien"
assert_codigo "$CODIGO" 0
caso "eligió postgres:18 y lo dijo"
assert_contiene "$SALIDA" "DB_CONNECTION=pgsql en el .env → motor postgres:18"
caso "ddev config recibió --database=postgres:18"
assert_contiene "$(cat "$TMP/adopt/llamadas")" "--database=postgres:18"
caso "dejó config.kit.yaml y el .env con pgsql y 5432"
assert_eq "$([ -f "$TMP/adopt/proy/.ddev/config.kit.yaml" ] && echo si)-$(grep -E '^DB_(CONNECTION|PORT)=' "$TMP/adopt/proy/.env" | tr '\n' ' ')" "si-DB_CONNECTION=pgsql DB_PORT=5432 "

echo "opciones de new-laravel (fallan antes de tocar nada)"
SALIDA=$(bash "$RAIZ/bin/new-laravel" app --kit angular 2>&1)
caso "--kit desconocido"
assert_contiene "$SALIDA" "--kit 'angular' no existe"
SALIDA=$(bash "$RAIZ/bin/new-laravel" app --db oracle 2>&1)
caso "--db desconocido"
assert_contiene "$SALIDA" "--db: usa mysql, mariadb o postgres"
SALIDA=$(bash "$RAIZ/bin/new-laravel" --rara app 2>&1)
caso "opción desconocida"
assert_contiene "$SALIDA" "Opción desconocida: --rara"
SALIDA=$(cd "$TMP" && bash "$RAIZ/bin/adopt-laravel" --db nada 2>&1)
caso "adopt-laravel --db desconocido"
assert_contiene "$SALIDA" "--db: usa mysql, mariadb o postgres"

resumen
