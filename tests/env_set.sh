#!/usr/bin/env bash
# env_set (lib/comun.sh): toca solo la primera coincidencia, descomenta, agrega.
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
# shellcheck source=../lib/comun.sh
. "$RAIZ/lib/comun.sh"
cd "$TMP" || exit 1

printf 'APP_NAME=Laravel\nDB_HOST=127.0.0.1\n# DB_HOST=otro\nDB_HOST_READ=x\n# MAIL_HOST=127.0.0.1\n' >.env
env_set DB_HOST db
caso "reemplaza la primera DB_HOST"
assert_eq "$(grep -c '^DB_HOST=db$' .env)" 1
caso "respeta la variante comentada de referencia"
assert_contiene "$(cat .env)" "# DB_HOST=otro"
caso "no toca claves con el mismo prefijo (DB_HOST_READ)"
assert_contiene "$(cat .env)" "DB_HOST_READ=x"
env_set MAIL_HOST 127.0.0.1
caso "descomenta si la clave solo existe comentada"
assert_eq "$(grep -c '^MAIL_HOST=127.0.0.1$' .env)" 1
env_set NUEVA valor
caso "agrega al final si no existe"
assert_eq "$(tail -1 .env)" "NUEVA=valor"
env_set NUEVA otro
caso "una segunda vez reemplaza, no duplica"
assert_eq "$(grep -c '^NUEVA=' .env)" 1
env_set AWS_URL 'https://a.ddev.site:10101/a\b&c'
caso "no interpreta barras invertidas ni & (van por ENVIRON)"
assert_contiene "$(cat .env)" 'AWS_URL=https://a.ddev.site:10101/a\b&c'
env_set APP_NAME 'Mi Tienda'
caso "valores con espacios"
assert_contiene "$(cat .env)" "APP_NAME=Mi Tienda"
caso "el archivo no queda con líneas de más"
assert_eq "$(wc -l <.env | tr -d ' ')" 7
env_set CLAVE v otro.env
caso "acepta otro archivo (lo crea si no existe)"
assert_eq "$(cat otro.env)" "CLAVE=v"
caso "no deja temporales"
assert_eq "$(find . -name '*.tmp' | wc -l | tr -d ' ')" 0

resumen
