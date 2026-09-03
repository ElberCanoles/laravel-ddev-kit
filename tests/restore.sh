#!/usr/bin/env bash
# restore-projects con ddev y docker simulados: clona desde el remoto guardado en el
# manifiesto, corre adopt-laravel, importa BD y storage; y falla claro cuando no hay
# ni carpeta ni remoto.
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

mkdir -p "$TMP/bin" "$TMP/respaldo" "$TMP/origen"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP/bin/docker"
cat >"$TMP/bin/ddev" <<FAKE
#!/usr/bin/env bash
# registra lo que le piden en $TMP/llamadas
echo "\$*" >>"$TMP/llamadas"
case "\$1" in
  describe) printf '{"raw":{"primary_url":"https://app.ddev.site","status":"running"}}\n' ;;
  config) mkdir -p .ddev && printf 'name: %s\ntype: laravel\n' "\$(basename "\$PWD")" >.ddev/config.yaml ;;
  *) exit 0 ;;
esac
FAKE
chmod +x "$TMP/bin/"*

# un repo "remoto" (bare) con un proyecto Laravel mínimo
git init -q "$TMP/origen/app" && (
  cd "$TMP/origen/app" || exit 1
  echo "#!/usr/bin/env php" >artisan
  printf 'APP_NAME=Laravel\nAPP_KEY=\nDB_HOST=127.0.0.1\n' >.env.example
  git add -A && git -c user.name=t -c user.email=t@t commit -qm inicial
)
git clone -q --bare "$TMP/origen/app" "$TMP/origen/app.git"
# el respaldo: manifiesto con remoto y approot que ya no existe, BD, .env y storage
jq -n --arg approot "$TMP/nuevo/app" --arg remoto "$TMP/origen/app.git" \
  '{nombre: "app", approot: $approot, remoto: $remoto, ddev: {php: "8.4", node: "22", database: "mysql:8.0"}, incluye: {bd: true, env: true, storage: true, minio: false}}' >"$TMP/respaldo/app.json"
echo "CREATE TABLE t (id int);" | gzip >"$TMP/respaldo/app.sql.gz"
printf 'APP_NAME=MiApp\nAPP_KEY=base64:secreto\nDB_HOST=db\n' >"$TMP/respaldo/app.env"
mkdir -p "$TMP/tmpst/storage/app/fotos" && echo "foto" >"$TMP/tmpst/storage/app/fotos/a.jpg"
tar czf "$TMP/respaldo/app-storage.tar.gz" -C "$TMP/tmpst" storage/app

echo "restauración completa"
SALIDA=$(cd "$TMP" && PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/restore-projects" "$TMP/respaldo" 2>&1)
CODIGO=$?
caso "termina bien"
assert_codigo "$CODIGO" 0
caso "clonó el repo en la ruta original"
if [ -f "$TMP/nuevo/app/artisan" ]; then pasa; else falla "$SALIDA"; fi
caso "restauró el .env del respaldo (no el .env.example)"
assert_contiene "$(cat "$TMP/nuevo/app/.env")" "APP_KEY=base64:secreto"
caso "adopt-laravel configuró DDEV con las versiones del respaldo"
assert_contiene "$(cat "$TMP/llamadas")" "config --project-type=laravel --docroot=public --php-version=8.4 --nodejs-version=22 --database=mysql:8.0"
caso "importó la base de datos del respaldo"
assert_contiene "$(cat "$TMP/llamadas")" "import-db --file=$TMP/respaldo/app.sql.gz"
caso "extrajo storage/app"
if [ -f "$TMP/nuevo/app/storage/app/fotos/a.jpg" ]; then pasa; else falla; fi
caso "resumen"
assert_contiene "$SALIDA" "Restaurados 1 de 1 proyectos"

echo "--en y --solo"
rm -rf "$TMP/nuevo" "$TMP/llamadas"
SALIDA=$(cd "$TMP" && PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/restore-projects" "$TMP/respaldo" --en "$TMP/otro" --solo app 2>&1)
caso "--en clona en la carpeta indicada"
if [ -f "$TMP/otro/app/artisan" ]; then pasa; else falla "$SALIDA"; fi
SALIDA=$(cd "$TMP" && PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/restore-projects" "$TMP/respaldo" --solo inexistente 2>&1)
caso "--solo con un nombre que no está: error claro"
assert_contiene "$SALIDA" "No hay proyectos que restaurar"

echo "carpeta de respaldo relativa"
rm -rf "$TMP/nuevo" "$TMP/llamadas"
SALIDA=$(cd "$TMP" && PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/restore-projects" respaldo --solo app 2>&1)
CODIGO=$?
caso "con ruta relativa termina bien"
assert_codigo "$CODIGO" 0
caso "con ruta relativa restaura el .env e importa la BD igual"
assert_eq "$(grep -c '^APP_KEY=base64:secreto$' "$TMP/nuevo/app/.env" 2>/dev/null)-$(grep -c 'import-db --file=' "$TMP/llamadas" 2>/dev/null)" "1-1"
caso "el resumen muestra la ruta absoluta"
assert_contiene "$SALIDA" "desde $TMP/respaldo"

echo "sin remoto ni carpeta"
mkdir -p "$TMP/respaldo2"
jq -n --arg approot "$TMP/nada/app2" '{nombre: "app2", approot: $approot, remoto: "", ddev: {}}' >"$TMP/respaldo2/app2.json"
echo "x" | gzip >"$TMP/respaldo2/app2.sql.gz"
SALIDA=$(cd "$TMP" && PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/restore-projects" "$TMP/respaldo2" 2>&1)
CODIGO=$?
caso "termina con código 1"
assert_codigo "$CODIGO" 1
caso "explica que hay que clonar a mano"
assert_contiene "$SALIDA" "clona el proyecto ahí"

echo "--personal"
export HOME="$TMP/home"
mkdir -p "$HOME/.ssh"
echo "nueva" >"$HOME/.ssh/id_actual"
mkdir -p "$TMP/tmpp/.ssh" && echo "vieja" >"$TMP/tmpp/.ssh/id_actual" && echo "otra" >"$TMP/tmpp/.ssh/id_vieja" && echo "[user]" >"$TMP/tmpp/.gitconfig"
tar czf "$TMP/respaldo/personal.tar.gz" -C "$TMP/tmpp" .ssh .gitconfig
rm -rf "$TMP/nuevo"
SALIDA=$(cd "$TMP" && PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/restore-projects" "$TMP/respaldo" --personal 2>&1)
caso "extrae lo que no existía"
assert_eq "$(cat "$HOME/.gitconfig" 2>/dev/null)-$(cat "$HOME/.ssh/id_vieja" 2>/dev/null)" "[user]-otra"
caso "no pisa lo que ya existía"
assert_eq "$(cat "$HOME/.ssh/id_actual")" "nueva"
caso "cuenta lo restaurado y lo saltado"
assert_contiene "$SALIDA" "2 archivo(s) restaurados en $HOME; 1 ya existían"
echo "basura" >"$TMP/respaldo/personal.tar.gz"
SALIDA=$(cd "$TMP" && PATH="$TMP/bin:$PATH" bash "$RAIZ/bin/restore-projects" "$TMP/respaldo" --solo app --personal 2>&1)
CODIGO=$?
caso "si personal.tar.gz está corrupto lo dice y sale con 1"
assert_eq "$CODIGO-$(printf '%s' "$SALIDA" | grep -c 'no pude extraer personal.tar.gz')" "1-1"

echo "ayuda"
SALIDA=$(bash "$RAIZ/bin/restore-projects" --help 2>&1)
caso "--help imprime el uso"
assert_contiene "$SALIDA" "Uso: restore-projects"

resumen
