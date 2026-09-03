# laravel-ddev-kit — Entorno Laravel reproducible (Debian/Ubuntu · macOS + DDEV)

Deja una máquina recién formateada — Linux (Debian, Ubuntu o derivados) o
macOS — lista para desarrollo Laravel profesional en ~15 minutos, con entornos
**idénticos y versionados por proyecto** gracias a [DDEV](https://ddev.com)
sobre Docker: aunque en el equipo convivan Linux y Mac, todos corren
exactamente el mismo entorno.

Cada proyecto define su versión de PHP, Node y MySQL en `.ddev/config.yaml`
(versionado dentro del repo del proyecto) y obtiene: dominio propio
`https://<proyecto>.ddev.site`, SSL confiable en el navegador, Mailpit (correo),
MinIO (S3 local), Vite con HMR y Xdebug listo para VS Code y PhpStorm.

> **¿Primer día con el kit?** 1) corre `bash setup.sh` (en Linux, cierra
> sesión y vuelve a entrar al terminar); 2) clona tu proyecto y ejecuta dentro
> [`adopt-laravel`](#adoptar-un-proyecto-existente) — o crea uno nuevo con
> [`new-laravel`](#crear-un-proyecto-nuevo) —; 3) trabaja con los comandos del
> [día a día](#día-a-día). Eso es todo. Si algo no anda: `kit-doctor`.

## Índice

- [Restauración después de formatear](#restauración-después-de-formatear)
- [Qué instala `setup.sh`](#qué-instala-setupsh) · [Qué toca en tu sistema](#qué-toca-en-tu-sistema)
- [Crear un proyecto nuevo](#crear-un-proyecto-nuevo)
- [Adoptar un proyecto existente](#adoptar-un-proyecto-existente)
- [Día a día](#día-a-día) — [Artisan y colas](#artisan-composer-y-colas) · [npm y Vite](#npm-y-vite-assets) · [MySQL](#base-de-datos-mysql) · [Mailpit](#correo-mailpit) · [MinIO](#archivos-s3-minio) · [logs y shell](#logs-y-shell)
- [Add-ons: Redis y otros servicios extra](#add-ons-redis-y-otros-servicios-extra)
- [Cambiar versiones (por proyecto)](#cambiar-versiones-por-proyecto)
- [Xdebug](#xdebug)
- [Proyectos Nuxt o solo Node](#proyectos-nuxt-o-solo-node)
- [Antes de formatear](#antes-de-formatear)
- [Actualizar o desinstalar el kit](#actualizar-o-desinstalar-el-kit)
- [Problemas típicos](#problemas-típicos)

## Restauración después de formatear

`setup.sh` detecta el sistema operativo y corre el instalador que corresponde
(`setup-debian.sh` o `setup-macos.sh`); los comandos de abajo sirven igual en
ambos.

**Linux (Debian, Ubuntu y derivados)**

```bash
sudo apt update && sudo apt install -y git                        # 1. git
git clone https://github.com/ElberCanoles/laravel-ddev-kit.git    # 2. el kit
cd laravel-ddev-kit && bash setup.sh                              # 3. instalador (pide sudo una vez)
# 4. cerrar sesión y volver a entrar (activa el grupo docker)
```

> **¿Qué Linux sirve?** Cualquier distro de la **familia Debian**: Debian,
> Ubuntu y sus derivados (Linux Mint, Pop!_OS, Zorin, elementary, KDE neon,
> LMDE, Kali…). El instalador detecta de cuál desciende la tuya y usa los repos
> de Debian o de Ubuntu según corresponda. Otras familias (Fedora/RHEL, Arch,
> openSUSE…) no están soportadas por ahora: el script se detiene y te lo dice.
>
> **¿Debian "puro" y no existe `sudo`?** Pasa cuando defines clave de root al
> instalar: Debian no instala `sudo` ni mete a tu usuario en el grupo. Como root
> (`su -`): `apt install -y sudo && usermod -aG sudo tu-usuario`, cierra sesión
> y vuelve a entrar. Ubuntu y la mayoría de derivados ya traen esto resuelto.

**macOS**

```bash
git clone https://github.com/ElberCanoles/laravel-ddev-kit.git    # 1. el kit (si macOS ofrece instalar
                                                                  #    las Command Line Tools, acepta)
cd laravel-ddev-kit && bash setup.sh                              # 2. instalador (instala Homebrew si falta)
# 3. la primera vez, acepta el asistente de Docker Desktop cuando se abra
```

**Y en ambos**, para terminar, si antes de formatear corriste
[`backup-projects`](#antes-de-formatear):

```bash
restore-projects /ruta/al/respaldo              # clona, configura DDEV e importa todo
restore-projects /ruta/al/respaldo --personal   # además tus llaves SSH, gitconfig, gh…
```

Por cada proyecto respaldado: si la carpeta no existe la clona del remoto que
guardó el respaldo, corre `adopt-laravel` con las mismas versiones de PHP, Node
y MySQL, e importa la base de datos, el `.env`, los archivos de `storage/app` y
los buckets de MinIO. Con `--en ~/Developer` eliges dónde clonar y con
`--solo mi-app` restauras uno. Si un proyecto no tenía remoto, te pide que lo
clones a mano y sigue con los demás.

Sin respaldo, el camino manual es clonar cada proyecto y correr dentro
`adopt-laravel` (o `ddev start` si ya trae `.ddev/`).

> **Consejo**: si adaptas el kit a tu equipo, haz un fork y clona el tuyo en el
> paso del clone; así tus cambios también sobreviven al formateo.

## Qué instala `setup.sh`

| Componente | En Linux (Debian/Ubuntu) | En macOS |
|---|---|---|
| Homebrew | — | lo instala si falta (también las Command Line Tools) |
| Docker | Docker Engine (repo oficial de Debian o de Ubuntu según tu base; si aún no hay paquetes para tu versión, usa la última estable) | Docker Desktop — o Colima / OrbStack, ver abajo |
| DDEV | repo apt oficial (`pkg.ddev.com`) | tap oficial de Homebrew (`ddev/ddev/ddev`) |
| mkcert → CA local, SSL confiable en `https://*.ddev.site` | apt o binario oficial | Homebrew (+ `nss` para Firefox) |
| Node.js LTS vía nvm (+ corepack habilita yarn/pnpm) | igual en ambos | ídem |
| PHP CLI + Composer (conveniencia; las versiones "de verdad" van por proyecto en DDEV) | paquetes apt | `brew install php composer` |
| GitHub CLI y VS Code, solo si faltan (PhpStorm va por JetBrains Toolbox; avisa si no está) | repos oficiales apt | casks de Homebrew |
| Extensiones VS Code: Xdebug, Intelephense, Laravel, Vue (Volar), EditorConfig | igual en ambos | ídem |
| Ajustes de sistema | más watchers inotify (Vite/HMR en proyectos grandes) | no hace falta |

Es **idempotente**: re-córrelo cuando quieras. Toggles: `INSTALL_DOCKER=0`,
`INSTALL_NATIVE_PHP=0`, `INSTALL_GH=0`, `INSTALL_IDES=0`, `INSTALL_VSCODE_EXTS=0`
(ejemplo: `INSTALL_GH=0 bash setup.sh`; `bash setup.sh --help` los lista).
Cada corrida deja un log en `~/.laravel-ddev-kit/`: si algo falla, el instalador
te dice en qué paso fue y dónde está el log. Los helpers de `bin/` quedan
enlazados en `~/.local/bin`, así funcionan con cualquier shell. Si mueves la
carpeta del kit, vuelve a correr `bash setup.sh` para re-enlazarlos.

### Docker en macOS: elegir proveedor

En macOS el motor de Docker corre dentro de una VM y hay varias apps que la
manejan. Si ya tienes una funcionando, el instalador la respeta y no toca nada;
si tienes una instalada pero apagada, la arranca. Solo si no hay ninguna
instala la que diga `DOCKER_PROVIDER` (sin variable: Docker Desktop):

| `DOCKER_PROVIDER=` | Qué es |
|---|---|
| `docker-desktop` | la app oficial de Docker; gratis para empresas pequeñas (<250 empleados y <10 M USD) |
| `colima` | libre/open source, por terminal, sin interfaz gráfica |
| `orbstack` | el más rápido y liviano; de pago para uso comercial |

Ejemplo: `DOCKER_PROVIDER=colima bash setup.sh`. Con Docker Desktop y OrbStack
la primera vez hay que aceptar su asistente gráfico; el script abre la app y
espera a que Docker responda.

## Qué toca en tu sistema

Todo lo que el instalador escribe fuera de tus proyectos, para que sepas qué
hay y cómo deshacerlo:

| Dónde | Qué | Linux | macOS |
|---|---|---|---|
| `/etc/apt/sources.list.d/` y `/etc/apt/keyrings/` | repos y llaves de Docker, DDEV y VS Code | ✓ | — |
| `/etc/apt/sources.list` | comenta la fuente `cdrom:` que deja el instalador de Debian (copia en `.kit-bak`) | ✓ | — |
| `/etc/sysctl.d/60-dev-inotify.conf` | más watchers de archivos para Vite/HMR | ✓ | — |
| grupo `docker` | mete a tu usuario para usar Docker sin sudo (equivale a root en la máquina: lo normal en un equipo de desarrollo) | ✓ | — |
| `~/.nvm/` | nvm y el Node LTS | ✓ | ✓ |
| `~/.local/bin/` | enlaces a los helpers de `bin/`: `new-laravel`, `adopt-laravel`, `backup-projects`, `restore-projects` y `kit-doctor` | ✓ | ✓ |
| `~/.bashrc` o `~/.zshrc` | `~/.local/bin` en el PATH si no estaba; nvm agrega sus propias líneas | ✓ | ✓ |
| `~/.zprofile` o `~/.bash_profile` | `brew shellenv` | — | ✓ |
| `~/.gitconfig` | `init.defaultBranch main` | ✓ | ✓ |
| `~/.ddev/` o `~/.config/ddev/` | config global de DDEV (telemetría desactivada) | ✓ | ✓ |
| CA de mkcert | en el almacén del sistema y de los navegadores (Linux: `~/.local/share/mkcert`; macOS: Llavero) | ✓ | ✓ |
| `~/.laravel-ddev-kit/` | un log por corrida del instalador | ✓ | ✓ |
| `/Applications` | Docker Desktop u OrbStack, y VS Code | — | ✓ |

Paquetes: en Linux por apt (`docker-ce`, `ddev`, `mkcert`, `php-*`, `gh`,
`code`); en macOS por Homebrew (`git`, `jq`, `nss`, `ddev`, `mkcert`, `php`,
`composer`, `gh`).

## Crear un proyecto nuevo

```bash
cd ~/Developer
new-laravel mi-app                     # PHP 8.5, Node 24, MySQL 8.4, esqueleto pelado
new-laravel mi-app --kit vue           # con un starter kit oficial: vue, react o livewire
new-laravel mi-app --db postgres       # motor: mysql, mariadb o postgres (con :version si quieres)
new-laravel mi-app --php 8.4 --node 22
new-laravel mi-app 8.4 22 8.0          # forma corta: [php] [node] [versión de mysql]
```

Entrega: Laravel + base de datos + Mailpit + MinIO (bucket creado y Flysystem
S3 instalado) + Vite/HMR + colas y scheduler corriendo solos + Xdebug +
`.vscode/launch.json` + git inicializado. Las URLs se imprimen al final.

Los starter kits van por detrás del esqueleto: hoy se basan en Laravel 12 y
con PHP 8.5 muestran avisos de deprecación de PDO en cada `artisan`. Si te
molestan, `--kit vue --php 8.4`.

Las opiniones del kit para el proyecto viven en **`.ddev/config.kit.yaml`**,
un archivo aparte que DDEV mezcla con `config.yaml`: los puertos de Vite, dos
daemons (`queue:listen` y `schedule:work`, que esperan a que exista `vendor/`)
y `corepack_enable`. Edítalo o bórralo a gusto y haz `ddev restart`; el kit no
lo vuelve a tocar.

## Adoptar un proyecto existente

```bash
cd mi-proyecto-clonado
adopt-laravel                          # deduce el motor del DB_CONNECTION de tu .env
adopt-laravel --db mariadb --php 8.4   # o dilo tú; forma corta: adopt-laravel 8.4 22 8.0
```

Si el proyecto ya trae `.ddev/` versionado (lo ideal), lo respeta: en ese caso
un simple `ddev start` también funciona. Si es la primera vez que el proyecto
ve DDEV, además deja `.ddev/config.kit.yaml` y configura Vite para DDEV.

## Día a día

Dos reglas explican casi todo lo que sigue:

1. **Todo con `ddev` delante.** Dentro de la carpeta del proyecto,
   `ddev artisan`, `ddev composer`, `ddev npm`… ejecutan el comando **dentro
   del contenedor**, con las versiones de PHP/Node/MySQL que el proyecto
   declara en `.ddev/config.yaml`. Evita usar el PHP o Node de tu máquina para
   el proyecto: la gracia es que todo el equipo corra exactamente el mismo
   entorno.
2. **Los servicios se llaman por su nombre.** Dentro del entorno, la base de
   datos es el host `db`, el S3 local es `minio` y Redis (si lo agregas) es
   `redis`. Por eso en `.env` va `DB_HOST=db` y no `127.0.0.1`. (La excepción
   es Mailpit, que corre dentro del propio contenedor web →
   `MAIL_HOST=127.0.0.1`.)

La chuleta:

| Acción | Comando |
|---|---|
| Levantar / apagar el proyecto | `ddev start` / `ddev stop` (todos a la vez: `ddev poweroff`) |
| Abrir la app en el navegador | `ddev launch` |
| Ver estado, URLs y puertos | `ddev describe` |
| Artisan / Composer / npm | `ddev artisan ...` / `ddev composer ...` / `ddev npm ...` |
| Vite con HMR (mientras desarrollas) | `ddev npm run dev` |
| Compilar assets | `ddev npm run build` |
| Consola MySQL | `ddev mysql` |
| Correo capturado (Mailpit) | `ddev launch -m` |
| Consola MinIO | `ddev minio` |
| Redis CLI (si instalaste el add-on) | `ddev redis-cli` |
| Colas y scheduler | ya corren solos dentro del contenedor; sus logs salen en `ddev logs -f` |
| Xdebug on/off | `ddev xdebug on` / `ddev xdebug off` (apagado = más rápido) |
| Shell dentro del contenedor | `ddev ssh` |
| Compartir tu entorno por internet | `ddev share` |

El detalle de cada tema, a continuación.

### Artisan, Composer y colas

```bash
ddev artisan migrate                # migraciones pendientes
ddev artisan migrate:fresh --seed   # recrear la BD desde cero con seeders
ddev artisan tinker                 # consola interactiva (probar código, mandar correos…)
ddev artisan test                   # tests (PHPUnit / Pest)
ddev logs -f                        # colas y scheduler ya corren solos (daemons en .ddev/config.kit.yaml)
ddev restart                        # …y se reinician con el proyecto si cambias algo en .ddev/
ddev artisan optimize:clear         # limpia todos los caches de Laravel ("no veo mis cambios")
ddev composer require vendor/paquete
```

### npm y Vite (assets)

¿Por qué `ddev npm` y no `npm` a secas? Porque usa el Node **del contenedor**
(la versión que declara `.ddev/config.yaml`, igual para todo el equipo) y
porque el dev server debe correr dentro para que el navegador lo alcance en
`https://<proyecto>.ddev.site:5173`.

```bash
ddev npm install        # tras clonar, o cuando cambie package.json
ddev npm run dev        # dev server de Vite con HMR — déjalo corriendo mientras desarrollas
ddev npm run build      # compila los assets a public/build (lo que usa la página
                        # cuando el dev server no está corriendo; lo que va a producción)
```

`new-laravel` deja `vite.config.js` listo para esto. Si adoptas un proyecto que
no lo trae, agrega esto dentro de su bloque `server: { ... }` (o crea el bloque):

```js
...(process.env.DDEV_PRIMARY_URL_WITHOUT_PORT ? {
    host: '0.0.0.0',
    port: 5173,
    strictPort: true,
    origin: `${process.env.DDEV_PRIMARY_URL_WITHOUT_PORT}:5173`,
    cors: { origin: /https?:\/\/([A-Za-z0-9\-\.]+)?(\.ddev\.site)(?::\d+)?$/ },
} : {}),
```

El condicional hace que solo aplique dentro de DDEV: el mismo archivo sigue
sirviendo a quien use Herd, Valet o Sail. Y ojo con crear un segundo bloque
`server`: en JavaScript gana el último y perderías esta configuración sin
ningún error.

### Base de datos (MySQL)

Dentro de los contenedores la BD vive en el host `db`, con base de datos,
usuario y clave `db` (root: `root` / `root`). El `.env` que dejan
`new-laravel` / `adopt-laravel` ya apunta ahí:

```dotenv
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=db
DB_USERNAME=db
DB_PASSWORD=db
```

```bash
ddev mysql                               # consola mysql (usuario db)
ddev mysql -uroot -proot                 # como root
ddev import-db --file=dump.sql.gz        # acepta .sql, .sql.gz, .zip…
ddev export-db --file=dump.sql.gz
ddev snapshot --name antes-del-refactor  # respaldo instantáneo antes de algo arriesgado
ddev snapshot restore --latest
```

¿Prefieres una GUI (TablePlus, DBeaver, Workbench…)? Conéctate a `127.0.0.1`
con el puerto que muestra `ddev describe` (cambia por proyecto), usuario `db`,
clave `db`.

### Correo (Mailpit)

Ningún correo sale a internet: todo lo que la app envíe queda capturado en
Mailpit. Ábrelo con `ddev launch -m` (o `https://<proyecto>.ddev.site:8026`).

El `.env` ya queda configurado por `new-laravel` / `adopt-laravel`; si lo
montas a mano son estas tres líneas (Mailpit escucha dentro del propio
contenedor web, por eso `127.0.0.1`):

```dotenv
MAIL_MAILER=smtp
MAIL_HOST=127.0.0.1
MAIL_PORT=1025
```

Prueba rápida:

```bash
ddev artisan tinker
>>> Mail::raw('¡Hola!', fn ($m) => $m->to('test@example.com')->subject('Prueba'));
# → aparece al instante en Mailpit
```

### Archivos S3 (MinIO)

MinIO es un S3 local: mismo código y misma configuración de Flysystem que
usarás en producción con AWS. `new-laravel` deja el disco `s3` apuntando a
MinIO con el bucket ya creado (mismo nombre del proyecto):

```dotenv
AWS_ACCESS_KEY_ID=ddevminio
AWS_SECRET_ACCESS_KEY=ddevminio
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=<proyecto>
AWS_ENDPOINT=http://minio:10101        # la app habla con el servicio 'minio'
AWS_USE_PATH_STYLE_ENDPOINT=true
AWS_URL=https://<proyecto>.ddev.site:10101/<proyecto>   # URL pública (navegador)
FILESYSTEM_DISK=s3                     # opcional: Storage:: usa MinIO por defecto
```

```bash
ddev minio                     # consola web (usuario ddevminio, clave ddevminio)
ddev mc ls minio/<bucket>      # cliente mc: listar archivos
ddev mc mb minio/otro-bucket   # crear otro bucket
```

Si adoptaste un proyecto que no trae MinIO:
`ddev add-on get ddev/ddev-minio && ddev restart`, agrega el bloque de arriba
al `.env`, crea el bucket (`ddev mc mb minio/<bucket>`) y, si falta, instala el
driver: `ddev composer require league/flysystem-aws-s3-v3`.

### Logs y shell

```bash
ddev logs -f                                  # logs de nginx/php (contenedor web)
ddev logs -s db                               # logs de MySQL
ddev exec tail -f storage/logs/laravel.log    # el log de Laravel
ddev ssh                                      # shell interactiva dentro del contenedor
ddev exec <comando>                           # ejecutar algo dentro sin entrar
```

## Add-ons: Redis y otros servicios extra

¿Tu proyecto necesita Redis, Elasticsearch, MongoDB…? En DDEV cada servicio
extra es un **add-on** que se instala con un comando. Los add-ons copian
archivos dentro de `.ddev/` — **commitéalos**: quien clone el proyecto tendrá
el servicio con solo `ddev start` (así instala MinIO este kit).

```bash
ddev add-on list                 # add-ons oficiales
ddev add-on list --all           # + los de la comunidad
ddev add-on list --installed     # los instalados en este proyecto
ddev add-on get ddev/ddev-redis  # instalar uno (después: ddev restart)
ddev add-on remove redis         # quitarlo
```

La configuración en `.env` sigue siempre el mismo patrón: el host es **el
nombre del servicio** (`redis`, `memcached`, `elasticsearch`…) y en local no
hay contraseñas. `ddev describe` lista todos los servicios activos del
proyecto.

### Redis paso a paso (cache, sesiones y colas)

**1. Instala el add-on** (una sola vez por proyecto; commitea los archivos que
crea en `.ddev/`):

```bash
ddev add-on get ddev/ddev-redis
ddev restart
```

**2. Configura `.env`.** Las tres primeras líneas conectan Laravel con Redis;
las otras tres deciden qué características lo usan — activa solo las que
necesites:

```dotenv
REDIS_CLIENT=phpredis   # la extensión phpredis ya viene en el contenedor de DDEV
REDIS_HOST=redis        # el add-on crea el servicio 'redis'
REDIS_PORT=6379

CACHE_STORE=redis       # cache   (en Laravel ≤ 10 la variable es CACHE_DRIVER)
SESSION_DRIVER=redis    # sesiones
QUEUE_CONNECTION=redis  # colas → se procesan con: ddev artisan queue:work
```

**3. Comprueba que funciona:**

```bash
ddev redis-cli ping     # → PONG
ddev artisan tinker
>>> Cache::put('saludo', 'hola'); Cache::get('saludo');   # → "hola"
```

Comandos útiles: `ddev redis-cli` (consola), `ddev redis-cli monitor` (ver en
vivo qué guarda tu app), `ddev redis-cli flushall` (vaciar todo).

### Otros add-ons útiles

| Add-on | Servicio | Típico en Laravel |
|---|---|---|
| `ddev/ddev-redis` | Redis | cache, sesiones, colas, Horizon |
| `ddev/ddev-memcached` | Memcached | cache |
| `ddev/ddev-elasticsearch` | Elasticsearch | búsqueda (Scout) |
| `ddev/ddev-mongo` | MongoDB | base de datos de documentos |
| `ddev/ddev-phpmyadmin` | phpMyAdmin | GUI web para MySQL: `ddev phpmyadmin` |
| `ddev/ddev-adminer` | Adminer | GUI web ligera para la BD: `ddev adminer` |
| `ddev/ddev-cron` | cron | cron dentro del contenedor web (para `schedule:run`) |
| `ddev/ddev-minio` | MinIO | S3 local (este kit ya lo instala) |

Cada add-on documenta sus detalles en su repo de GitHub
(`https://github.com/<owner>/<repo>`). ¿Buscas otro (Meilisearch, RabbitMQ…)?
`ddev add-on list --all | grep -i <nombre>`.

## Cambiar versiones (por proyecto)

Edita `.ddev/config.yaml` → `php_version`, `nodejs_version` → `ddev restart`.
En general, cualquier cambio dentro de `.ddev/` (versiones, add-ons, puertos)
se aplica con `ddev restart`.

⚠ Cambiar `database` (motor o versión) exige borrar los datos del proyecto:
`ddev export-db --file=antes.sql.gz && ddev delete -y && ddev start`.

## Xdebug

Activa con `ddev xdebug on` y luego:

- **VS Code**: `F5` con la configuración "Escuchar Xdebug (DDEV)" (ya incluida
  en `.vscode/launch.json` por `new-laravel`/`adopt-laravel`).
- **PhpStorm**: clic en el teléfono verde ("Start Listening for PHP Debug
  Connections"), breakpoint, recargar la página; en el diálogo de conexión
  entrante mapear `/var/www/html` → raíz del proyecto (una sola vez).
  Recomendado: plugin **DDEV Integration** desde el marketplace.

Puerto 9003 en ambos IDEs. Apágalo al terminar: `ddev xdebug off`.

## Proyectos Nuxt o solo Node

Un Nuxt puro no necesita DDEV: con el Node de nvm basta (`npm run dev`).
Si quieres dominio + SSL también ahí, DDEV soporta proyectos Node
(quickstart "Node.js" en la documentación de DDEV).

## Antes de formatear

```bash
backup-projects /media/usb/respaldo           # a un disco externo o a la nube
backup-projects /media/usb/respaldo --personal
```

De cada proyecto DDEV de la máquina guarda la base de datos, el `.env`, los
archivos subidos de `storage/app`, los buckets de MinIO y un manifiesto con la
ruta, el remoto git y las versiones de PHP, Node y MySQL, que es lo que
`restore-projects` usa después. Sin carpeta va a `~/respaldos-ddev/<fecha>/`,
que está en el disco que vas a formatear: cópiala fuera.

- `--personal` añade `~/.ssh`, `~/.gitconfig`, la sesión de `gh`, los tokens de
  Composer y npm y la config global de DDEV en un `personal.tar.gz` solo legible
  por ti. Son secretos en claro: por eso no va por defecto.
- `--solo-bd` guarda solo base de datos y `.env` (rápido).
- `--solo mi-app` respalda un solo proyecto.

Si un proyecto falla (carpeta borrada, no levanta) sigue con los demás y los
lista al final. Y haz push de todos tus repos, incluido este.

## Actualizar o desinstalar el kit

**Actualizar.** El kit es un clon de git: trae los cambios y vuelve a correr el
instalador, que solo aplica lo que falte. Los helpers son enlaces a `bin/`, así
que se actualizan solos.

```bash
cd laravel-ddev-kit && git pull && bash setup.sh
```

**Desinstalar** el kit sin tocar Docker, DDEV ni tus proyectos:

```bash
rm ~/.local/bin/{new-laravel,adopt-laravel,backup-projects,restore-projects,kit-doctor}
rm -rf ~/.laravel-ddev-kit    # logs
rm -rf laravel-ddev-kit       # el clon
```

Si además quieres quitar las herramientas: en Linux, `sudo apt remove ddev
docker-ce docker-ce-cli containerd.io` y borra sus `.list` de
`/etc/apt/sources.list.d/`; en macOS, `brew uninstall ddev/ddev/ddev mkcert` y
`brew uninstall --cask docker-desktop` (u `orbstack`). Antes de quitar Docker
corre `backup-projects`: las bases de datos viven en volúmenes de Docker.

## Problemas típicos

Empieza por `kit-doctor`: revisa la máquina (Docker, DDEV, CA de mkcert, DNS,
puertos, inotify, PATH, espacio) y, si lo corres dentro de un proyecto, también
el proyecto (`.env`, `vendor/` y `node_modules/` al día, Vite, estado en DDEV).
Cada línea dice qué falló y cómo arreglarlo.

- **`permission denied ... docker.sock`** (Linux) → falta re-loguear tras
  `setup.sh` (grupo docker).
- **`Cannot connect to the Docker daemon`** (macOS) → abre Docker Desktop u
  OrbStack, o corre `colima start`, según tu proveedor.
- **`Operation not permitted` al instalar una app con brew** (macOS) → tu
  Terminal necesita el permiso **"Gestión de apps"**: Ajustes del Sistema →
  Privacidad y seguridad → Gestión de apps → actívalo para tu Terminal,
  reábrelo y re-corre `bash setup.sh` (a `sudo` ese permiso no le basta).
- **Puerto 80/443 ocupado al `ddev start`** → en Linux:
  `sudo systemctl disable --now apache2` (o el nginx que estorbe); en macOS:
  `sudo apachectl stop` si tienes activo el Apache del sistema.
- **Las URLs salen con puerto raro (`:33001`) o `https://*.ddev.site` muestra un
  certificado de "Laravel Valet"** (macOS) → Valet tiene tomado
  `127.0.0.1:80/443`; DDEV lo detecta y se mueve a puertos alternativos, así que
  todo funciona igual (las URLs reales las imprime `ddev describe`). Para URLs
  sin puerto: `valet stop` antes de `ddev start` — o desinstala Valet si ya
  migraste del todo a DDEV.
- **Instalaste un add-on y el servicio no aparece** → `ddev restart` y
  revísalo en `ddev describe`.
- **"No veo mis cambios" (config, rutas o vistas cacheadas)** →
  `ddev artisan optimize:clear`.
- **Mi `.env` vuelve a `DB_HOST=db` (o a `APP_URL` de DDEV) aunque lo cambie** →
  es DDEV: en proyectos tipo laravel reescribe `APP_URL`, `DB_*` y `MAIL_*` en
  cada `ddev start`. Si de verdad quieres otra cosa (p. ej. sqlite en local),
  pon `disable_settings_management: true` en `.ddev/config.yaml`.
- **Un job de la cola no toma mis cambios de código** → el daemon usa
  `queue:listen`, que recarga en cada job; si lo cambiaste a `queue:work`,
  reinícialo con `ddev restart`.
- **Docker aún no publica para tu versión de Debian/Ubuntu** → el script cae
  solo a la última estable y te avisa; si prefieres fijarla tú:
  `DOCKER_CODENAME=noble bash setup.sh` (Ubuntu) o `DOCKER_CODENAME=trixie bash setup.sh` (Debian).
- **Sin internet `*.ddev.site` no resuelve** → DDEV cae a `/etc/hosts`
  automáticamente (pedirá sudo al hacer `ddev start`).
- **`Estás en WSL`** al correr `setup.sh` → el kit no soporta Windows/WSL
  todavía: el navegador vive en Windows y la CA de mkcert hay que instalarla
  allá. Sigue la guía de DDEV para Windows.
- **`Tienes el Docker de snap`** → DDEV no funciona bien con él:
  `sudo snap remove docker` y re-corre `bash setup.sh`.
- **`apt-get update` pide el CD de instalación** (Debian) → el instalador
  desactiva solo la fuente `cdrom:`; si te pasa en otro momento, comenta la
  línea `deb cdrom:` de `/etc/apt/sources.list`.
- **`new-laravel` rechaza el nombre** → el nombre es el dominio
  (`https://<nombre>.ddev.site`): solo letras, dígitos y guiones. Te sugiere uno.
- **`backup-projects` terminó con proyectos sin respaldo** → revisa la lista que
  imprime: carpeta borrada o proyecto que no levanta. Si ya no existe,
  `ddev stop --unlist <nombre>` lo saca de la lista.
- **El instalador se detuvo con `✖ Falló en «…»`** → el mensaje dice el paso y
  el comando; el log completo queda en `~/.laravel-ddev-kit/`. Corrige la causa
  y vuelve a correrlo: es idempotente y salta lo ya hecho.
- **Diagnóstico general** → `ddev debug test`.

---

¿Quieres mejorar el kit? Mira [CONTRIBUTING.md](CONTRIBUTING.md): pruebas con
`bash tests/run.sh`, shellcheck y shfmt. Los cambios se anotan en
[CHANGELOG.md](CHANGELOG.md).
