#!/usr/bin/env bash
# backup-projects con ddev y docker simulados: un proyecto con carpeta borrada, uno
# detenido (la primera exportación falla, se levanta y se reintenta) y uno sano con
# archivos en storage/app. También --solo-bd y --personal.
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

mkdir -p "$TMP/bin" "$TMP/proys/dormido/.ddev" "$TMP/proys/sano/.ddev" "$TMP/proys/sano/storage/app/fotos" "$TMP/dest"
echo "APP_KEY=x" >"$TMP/proys/dormido/.env"
echo "APP_KEY=y" >"$TMP/proys/sano/.env"
echo "foto" >"$TMP/proys/sano/storage/app/fotos/a.jpg"
# mismo formato que escribe DDEV: el bloque database va con 4 espacios
printf 'name: sano\ntype: laravel\nphp_version: "8.5"\nnodejs_version: "24"\ndatabase:\n    type: mysql\n    version: "8.4"\n' >"$TMP/proys/sano/.ddev/config.yaml"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP/bin/docker"
# 'sano' es un repo git con un remoto que lleva credenciales: no deben llegar al manifiesto
(cd "$TMP/proys/sano" && git init -q && git remote add origin "https://usuario:token-secreto@github.com/equipo/sano.git")
cat >"$TMP/bin/ddev" <<FAKE
#!/usr/bin/env bash
case "\$1" in
  list) printf '{"raw":[{"name":"roto","approot":"$TMP/proys/roto"},{"name":"dormido","approot":"$TMP/proys/dormido"},{"name":"sano","approot":"$TMP/proys/sano"}]}\n' ;;
  export-db)
    [ -t 0 ] || cat >/dev/null # como el ddev real: si stdin no es una terminal lo reenvía al contenedor (y lo consume)
    f=\${2#--file=}
    if [ "\$(basename "\$PWD")" = dormido ] && [ ! -f "\$PWD/.arrancado" ]; then echo "Project is not running" >&2; exit 1; fi
    echo "dump de \$(basename "\$PWD")" | gzip >"\$f" ;;
  start) touch "\$PWD/.arrancado" ;;
  *) exit 2 ;;
esac
FAKE
chmod +x "$TMP/bin/"*
export HOME="$TMP/home"
mkdir -p "$HOME/.ssh" "$HOME/.config/gh"
echo "clave" >"$HOME/.ssh/id_prueba"
echo "[user]" >"$HOME/.gitconfig"
echo "token" >"$HOME/.config/gh/hosts.yml"

echo "respaldo completo"
SALIDA=$(PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/backup-projects" "$TMP/dest" 2>&1)
CODIGO=$?
caso "termina con código 1 porque un proyecto quedó sin respaldo"
assert_codigo "$CODIGO" 1
caso "sigue después del proyecto roto"
assert_contiene "$SALIDA" "2 de 3 proyectos"
caso "recorre los 3 proyectos aunque ddev se trague stdin (la lista va por fd 3)"
assert_eq "$(printf '%s' "$SALIDA" | grep -c '^==> ')" 3
caso "lista el que falló"
assert_contiene "$SALIDA" "Sin respaldo: roto"
caso "levanta el proyecto detenido y lo exporta"
assert_contiene "$SALIDA" "lo levanto para exportar"
caso "respalda storage/app cuando tiene archivos"
assert_contiene "$SALIDA" "✔ storage/app"
caso "archivos generados"
assert_eq "$(cd "$TMP/dest" && find . -type f | sed 's#^\./##' | LC_ALL=C sort | tr '\n' ' ')" "dormido.env dormido.json dormido.sql.gz sano-storage.tar.gz sano.env sano.json sano.sql.gz "
caso "el dump es un gzip con contenido"
assert_eq "$(gzip -dc "$TMP/dest/sano.sql.gz")" "dump de sano"
caso "el tar de storage trae el archivo"
assert_contiene "$(tar tzf "$TMP/dest/sano-storage.tar.gz")" "storage/app/fotos/a.jpg"
caso "el manifiesto guarda approot y versiones de .ddev/config.yaml"
assert_eq "$(jq -r '[.approot, .ddev.php, .ddev.node, .ddev.database, .incluye.storage, .incluye.minio] | join(" ")' "$TMP/dest/sano.json")" "$TMP/proys/sano 8.5 24 mysql:8.4 true false"
caso "el manifiesto guarda el remoto sin usuario ni token"
assert_eq "$(jq -r '.remoto' "$TMP/dest/sano.json")" "https://github.com/equipo/sano.git"
caso "los archivos del respaldo nacen solo legibles por el usuario (600)"
assert_eq "$(stat -c %a "$TMP/dest/sano.env" 2>/dev/null || stat -f %Lp "$TMP/dest/sano.env")-$(stat -c %a "$TMP/dest/sano.sql.gz" 2>/dev/null || stat -f %Lp "$TMP/dest/sano.sql.gz")" "600-600"
caso "sin .ddev/config.yaml el manifiesto marca versiones desconocidas"
assert_eq "$(jq -r '[.ddev.php, .ddev.node, .ddev.database] | join(" ")' "$TMP/dest/dormido.json")" "- - -"
caso "la carpeta de respaldo queda solo para el usuario (700)"
assert_eq "$(stat -c %a "$TMP/dest" 2>/dev/null || stat -f %Lp "$TMP/dest")" "700"
caso "recuerda restore-projects"
assert_contiene "$SALIDA" "restore-projects $TMP/dest"
caso "sin --personal recuerda que existe"
assert_contiene "$SALIDA" "Con --personal"

echo "--solo-bd"
rm -rf "$TMP/dest" && mkdir -p "$TMP/dest"
SALIDA=$(PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/backup-projects" "$TMP/dest" --solo-bd 2>&1)
caso "no respalda storage"
assert_no_contiene "$(cd "$TMP/dest" && find . -type f | sort | tr '\n' ' ')" "storage"

echo "--personal"
rm -rf "$TMP/dest" && mkdir -p "$TMP/dest"
SALIDA=$(PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/backup-projects" "$TMP/dest" --personal 2>&1)
caso "crea personal.tar.gz con lo que existe"
assert_contiene "$(tar tzf "$TMP/dest/personal.tar.gz" 2>/dev/null | sort | tr '\n' ' ')" ".ssh/id_prueba"
caso "personal.tar.gz incluye .gitconfig y la sesión de gh"
assert_eq "$(tar tzf "$TMP/dest/personal.tar.gz" | grep -cE '^(\.gitconfig|\.config/gh/hosts\.yml)$')" 2
caso "personal.tar.gz queda solo legible por el usuario (600)"
assert_eq "$(stat -c %a "$TMP/dest/personal.tar.gz" 2>/dev/null || stat -f %Lp "$TMP/dest/personal.tar.gz")" "600"
caso "avisa que contiene secretos"
assert_contiene "$SALIDA" "llaves privadas y tokens"

echo "--solo"
rm -rf "$TMP/dest" && mkdir -p "$TMP/dest"
SALIDA=$(PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/backup-projects" "$TMP/dest" --solo sano 2>&1)
CODIGO=$?
caso "--solo respalda únicamente ese proyecto y termina bien"
assert_eq "$CODIGO-$(printf '%s' "$SALIDA" | grep -c '^==> ')" "0-1"
caso "--solo con un nombre inexistente: error claro"
SALIDA=$(PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/backup-projects" "$TMP/dest" --solo nada 2>&1)
assert_contiene "$SALIDA" "No hay ningún proyecto DDEV llamado 'nada'"

echo "opciones"
SALIDA=$(PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/backup-projects" --help 2>&1)
caso "--help imprime el uso"
assert_contiene "$SALIDA" "Uso: backup-projects"
SALIDA=$(PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/backup-projects" --rara 2>&1)
caso "opción desconocida: error claro"
assert_contiene "$SALIDA" "Opción desconocida: --rara"

resumen
