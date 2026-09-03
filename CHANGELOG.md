# Changelog

Formato: [Keep a Changelog](https://keepachangelog.com/es/1.1.0/). Versiones
según [SemVer](https://semver.org/lang/es/).

## Sin publicar

### Agregado

- `new-laravel --kit vue|react|livewire` (starter kits oficiales),
  `--db mysql|mariadb|postgres[:version]`, `--php`, `--node`; la forma
  posicional sigue funcionando.
- `adopt-laravel --db/--php/--node`; sin `--db` deduce el motor del
  `DB_CONNECTION` del `.env`. Al crear el `.ddev/` configura también Vite.
- `.ddev/config.kit.yaml` (plantilla en `templates/ddev/`): puertos de Vite,
  daemons `queue:listen` y `schedule:work` que esperan a `vendor/`, y
  `corepack_enable`. Sustituye al bloque que se agregaba a `config.yaml`.
- `.env` por motor: `pgsql`/5432 para Postgres, `mariadb` si el proyecto
  declara esa conexión.
- `restore-projects` pasa el motor respaldado a `adopt-laravel` con `--db`.
- README: la nota sobre el `.env` que DDEV reescribe en cada `ddev start`.
- Composer siempre con `--no-interaction`: `ddev composer create-project` con un
  starter kit se quedaba esperando una respuesta por stdin.
- `restore-projects`: levanta en una máquina nueva todo lo que guardó
  `backup-projects` (clona del remoto, `adopt-laravel` con las versiones
  respaldadas, importa BD, `.env`, `storage/app` y buckets de MinIO;
  `--en`, `--solo`, `--personal`).
- `backup-projects` respalda también `storage/app`, los buckets de MinIO y un
  manifiesto por proyecto; `--personal` (llaves SSH, gitconfig, gh, tokens de
  Composer y npm, config de DDEV), `--solo-bd` y `--solo <proyecto>`.
- `kit-doctor`: diagnóstico de la máquina y, dentro de un proyecto, del
  proyecto, con la solución al lado de cada problema.
- Biblioteca compartida `lib/comun.sh` (mensajes, `env_set`, chequeos) usada
  por instaladores y helpers.
- Los instaladores guardan un log de cada corrida en `~/.laravel-ddev-kit/` y,
  si algo falla, dicen en qué paso y dónde está el log.
- `--help` en `setup.sh` y en los helpers de `bin/`.
- Los helpers se instalan como enlaces en `~/.local/bin`, así funcionan con
  cualquier shell sin tocar el PATH (si mueves el clon, re-corre `setup.sh`).
- Pruebas en `tests/` y CI en GitHub Actions (lint + pruebas + instalación real
  en contenedores de Debian 12, Debian 13, Ubuntu 24.04 y Ubuntu 26.04).
- Toggle `INSTALL_DOCKER=0` en ambos instaladores (otro Docker, o CI).
- LICENSE (MIT), CONTRIBUTING, `.editorconfig`, `.shellcheckrc` y este CHANGELOG.
- README: "Qué toca en tu sistema" y "Actualizar o desinstalar el kit".
- CI: `workflow_dispatch` para lanzarlo a mano desde la pestaña Actions. Con el
  repo público, el job de macOS ya corre en cada PR.

### Cambiado

- `setup-debian.sh` registra todos los repositorios de una vez: dos
  `apt-get update` en total en vez de cuatro.
- Colores solo cuando la salida es una terminal (y se respeta `NO_COLOR`).
- Los valores de `env_set` viajan por `ENVIRON`: awk ya no interpreta barras
  invertidas.
- `setup-macos.sh` instala el CLI `docker` de brew solo para Colima (Docker
  Desktop y OrbStack traen el suyo).
- README: los pasos de clonado usan la URL pública del kit; el consejo pasa a
  ser "haz un fork si lo adaptas a tu equipo".

### Corregido

- `backup-projects` podía respaldar solo el primer proyecto y reportar éxito: la
  lista de proyectos entraba por stdin y `ddev` (que reenvía stdin al contenedor
  cuando no es una terminal) se tragaba el resto. La lista va ahora por el
  descriptor 3.
- `backup-projects` y `restore-projects` con una carpeta relativa: restore no
  importaba nada y decía que todo fue bien; backup fallaba con un mensaje
  confuso. Ambos resuelven la ruta a absoluta antes de entrar a cada proyecto.
- `setup-debian.sh` crea `/etc/sysctl.d` si no existe (imágenes mínimas de
  Debian 12).
- `nombre_valido` usa locale C: en es_ES/en_US.UTF-8 el rango `a-z` aceptaba
  letras acentuadas.
- mkcert desde GitHub: nombre correcto del binario en armhf y aviso claro si la
  API de GitHub no responde.

## [0.2.0] - 2026-09-01

### Corregido

- `new-laravel`: el HMR de Vite quedaba roto en silencio porque el esqueleto
  actual de Laravel ya trae un bloque `server` y se creaba un segundo bloque.
  Ahora se fusiona dentro del existente, con un spread condicional que solo
  aplica dentro de DDEV.
- `backup-projects` abortaba en el primer proyecto que fallaba; ahora sigue,
  resume y sale con código 1 listando los que quedaron sin respaldo.
- `new-laravel` valida el nombre, las herramientas y Docker antes de crear
  nada, y explica cómo limpiar si algo falla a medio camino.
- El fallback de URL cuando `ddev describe` falla abortaba el script.

### Cambiado

- Defaults: PHP 8.5, Node 24 y MySQL 8.4 (8.0 sin soporte desde abril de 2026).
- `setup-debian.sh`: `apt-get` sin diálogos, fuente `cdrom:` de Debian
  desactivada, Docker de snap detenido con instrucciones, WSL detectado y
  remitido a la guía de DDEV.

## [0.1.0] - 2026-08-31

### Agregado

- Instaladores para la familia Debian (Debian, Ubuntu y derivados) y macOS.
- Helpers `new-laravel`, `adopt-laravel` y `backup-projects`.
- README completo en español para quien llega por primera vez a DDEV.
