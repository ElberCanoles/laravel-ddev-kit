#!/usr/bin/env bash
# lib/laravel.sh — lo que comparten new-laravel y adopt-laravel: puertos de Vite en
# .ddev, bloques de .env y la configuración del dev server de Vite.
# Requiere lib/comun.sh cargado antes.

# Las opiniones del kit para el proyecto (puertos de Vite, colas y scheduler como
# daemons, corepack) van en .ddev/config.kit.yaml, que DDEV mezcla con config.yaml.
# Un archivo aparte deja claro qué puso el kit y se puede editar o borrar sin miedo.
ddev_config_kit() { # ddev_config_kit <raiz-del-kit>
  if [ -f .ddev/config.kit.yaml ]; then return 0; fi
  cp "$1/templates/ddev/config.kit.yaml" .ddev/config.kit.yaml
}

# Lo que dice .ddev/config.yaml (DDEV lo escribe con 4 espacios; se acepta cualquiera).
ddev_php_configurado() { sed -n 's/^php_version: *"\{0,1\}\([^"]*\)"\{0,1\}.*/\1/p' .ddev/config.yaml 2>/dev/null | head -1; }
ddev_node_configurado() { sed -n 's/^nodejs_version: *"\{0,1\}\([^"]*\)"\{0,1\}.*/\1/p' .ddev/config.yaml 2>/dev/null | head -1; }
ddev_db_configurada() { # imprime tipo:version, o nada si no está declarada (o no hay config)
  [ -f .ddev/config.yaml ] || return 0
  awk '/^database:/ {f=1; next} f && /^[[:space:]]+type:/ {t=$2} f && /^[[:space:]]+version:/ {v=$2} f && /^[^[:space:]]/ {f=0} END {gsub(/"/, "", t); gsub(/"/, "", v); if (t != "") print t ":" v}' .ddev/config.yaml 2>/dev/null
}

# Motor de base de datos para DDEV: mysql, mariadb o postgres (también pgsql y
# postgresql), con o sin versión. Imprime tipo:version; devuelve 1 si no lo reconoce.
normalizar_db() { # normalizar_db postgres → postgres:18
  local tipo=$1 ver=""
  case "$1" in *:*)
    tipo=${1%%:*}
    ver=${1#*:}
    ;;
  esac
  case "$tipo" in
    mysql) printf 'mysql:%s' "${ver:-8.4}" ;;
    mariadb) printf 'mariadb:%s' "${ver:-11.8}" ;;
    postgres | postgresql | pgsql) printf 'postgres:%s' "${ver:-18}" ;;
    *) return 1 ;;
  esac
}

# Driver de Laravel para cada motor. 'mariadb' solo si el proyecto lo declara en
# config/database.php (Laravel 11+); si no, el driver mysql también sirve.
driver_laravel() { # driver_laravel <tipo>
  case "$1" in
    postgres) echo pgsql ;;
    mariadb) if grep -q "'mariadb' =>" config/database.php 2>/dev/null; then echo mariadb; else echo mysql; fi ;;
    *) echo mysql ;;
  esac
}

# .env apuntando a los servicios de DDEV: la BD es el host 'db' (bd, usuario y clave
# 'db'); Mailpit escucha dentro del propio contenedor web, por eso 127.0.0.1. DDEV
# escribe estos mismos valores en cada `ddev start` de un proyecto tipo laravel;
# aquí quedan listos desde el primer momento.
env_laravel_ddev() { # env_laravel_ddev <url-de-la-app> [motor tipo:version, default mysql]
  local motor=${2:-mysql} tipo
  tipo=${motor%%:*}
  env_set APP_URL "$1"
  env_set DB_CONNECTION "$(driver_laravel "$tipo")"
  env_set DB_HOST db
  if [ "$tipo" = postgres ]; then env_set DB_PORT 5432; else env_set DB_PORT 3306; fi
  env_set DB_DATABASE db
  env_set DB_USERNAME db
  env_set DB_PASSWORD db
  env_set MAIL_MAILER smtp
  env_set MAIL_HOST 127.0.0.1
  env_set MAIL_PORT 1025
}

# .env para MinIO (S3 local del add-on ddev/ddev-minio): la app habla con el servicio
# 'minio' por dentro; la URL pública (navegador) pasa por el router de DDEV.
env_minio() { # env_minio <nombre-proyecto>
  env_set AWS_ACCESS_KEY_ID ddevminio
  env_set AWS_SECRET_ACCESS_KEY ddevminio
  env_set AWS_DEFAULT_REGION us-east-1
  env_set AWS_BUCKET "$1"
  env_set AWS_ENDPOINT "http://minio:10101"
  env_set AWS_USE_PATH_STYLE_ENDPOINT true
  env_set AWS_URL "https://$1.ddev.site:10101/$1"
}

# Dev server de Vite alcanzable desde el navegador a través de DDEV. Receta oficial
# envuelta en un spread condicional: solo aplica cuando Vite corre dentro de DDEV,
# así el mismo archivo sigue sirviendo a quien use Herd, Valet o Sail.
#
# Si el archivo ya trae un bloque server (el esqueleto de Laravel y los starter kits
# lo traen, con watch.ignored) se inserta DENTRO: en JavaScript una clave repetida
# se queda con el último valor, así que un segundo bloque server perdería toda esta
# configuración en silencio.
#
# Las anclas (la línea "server: {" o la de "defineConfig({") tienen que terminar en
# "{", con un comentario // como mucho: así lo insertado queda dentro de ese objeto y
# el resultado es válido en JS y en TS sin depender de Node para comprobarlo. En JS
# se valida igualmente con el Node del contenedor antes de reemplazar; en TS no,
# porque ese Node puede no entender los tipos.
configurar_vite() {
  local archivo="" f
  for f in vite.config.js vite.config.mjs vite.config.ts vite.config.mts; do
    if [ -f "$f" ]; then
      archivo=$f
      break
    fi
  done
  if [ -z "$archivo" ]; then
    aviso "No encontré vite.config.*; el HMR de Vite queda por configurar (README → npm y Vite)"
    return 0
  fi
  if grep -q 'DDEV_PRIMARY_URL_WITHOUT_PORT' "$archivo"; then
    return 0 # ya está configurado
  fi
  if grep -qE '^[[:space:]]+(host|origin|strictPort):' "$archivo"; then
    aviso "$archivo ya trae configuración propia de server (host/origin); revísalo a mano (README → npm y Vite)"
    return 0
  fi
  local modo
  if grep -qE '^[[:space:]]*server[[:space:]]*:[[:space:]]*\{[[:space:]]*(//.*)?$' "$archivo"; then
    modo=fusionar
  elif grep -qE '^[[:space:]]*server[[:space:]]*:' "$archivo"; then
    aviso "$archivo trae un bloque server en un formato que no reconozco (¿en una sola línea?); agrega la configuración a mano (README → npm y Vite)"
    return 0
  elif grep -qE 'defineConfig\(\{[[:space:]]*(//.*)?$' "$archivo"; then
    modo=crear
  else
    aviso "No reconocí la estructura de $archivo; agrega el bloque server a mano (README → npm y Vite)"
    return 0
  fi
  local tmp="${archivo%.*}.kit-tmp.${archivo##*.}"
  awk -v modo="$modo" '
    function ddev(ind) {
      print ind "...(process.env.DDEV_PRIMARY_URL_WITHOUT_PORT ? {"
      print ind "    host: \"0.0.0.0\","
      print ind "    port: 5173,"
      print ind "    strictPort: true,"
      print ind "    origin: `${process.env.DDEV_PRIMARY_URL_WITHOUT_PORT}:5173`,"
      print ind "    cors: {"
      print ind "        origin: /https?:\\/\\/([A-Za-z0-9\\-\\.]+)?(\\.ddev\\.site)(?::\\d+)?$/,"
      print ind "    },"
      print ind "} : {}),"
    }
    { print }
    !hecho && modo == "fusionar" && /^[[:space:]]*server[[:space:]]*:[[:space:]]*\{[[:space:]]*(\/\/.*)?$/ {
      match($0, /^[[:space:]]*/); ddev(substr($0, 1, RLENGTH) "    "); hecho = 1
    }
    !hecho && modo == "crear" && /defineConfig\(\{[[:space:]]*(\/\/.*)?$/ {
      print "    server: {"; ddev("        "); print "    },"; hecho = 1
    }
  ' "$archivo" >"$tmp"
  case "$archivo" in
    *.js | *.mjs)
      if ! ddev exec node --check "/var/www/html/$tmp" >/dev/null 2>&1; then
        rm -f "$tmp"
        aviso "El $archivo resultante no pasó la comprobación de sintaxis; lo dejé como estaba. Configura el bloque server a mano (README → npm y Vite)"
        return 0
      fi
      ;;
  esac
  mv "$tmp" "$archivo"
  ok "$archivo: dev server de Vite configurado para DDEV"
}
