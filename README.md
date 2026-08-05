# machine-setup — Entorno Laravel reproducible (Ubuntu + DDEV)

Deja una máquina Ubuntu recién formateada lista para desarrollo Laravel
profesional en ~15 minutos, con entornos **idénticos y versionados por proyecto**
gracias a [DDEV](https://ddev.com) sobre Docker.

Cada proyecto define su versión de PHP, Node y MySQL en `.ddev/config.yaml`
(versionado dentro del repo del proyecto) y obtiene: dominio propio
`https://<proyecto>.ddev.site`, SSL confiable en el navegador, Mailpit (correo),
MinIO (S3 local), Vite con HMR y Xdebug listo para VS Code y PhpStorm.

## ⚡ Restauración después de formatear

```bash
sudo apt update && sudo apt install -y git          # 1. git
git clone <TU-REMOTO>/machine-setup.git             # 2. este repo
cd machine-setup && bash setup.sh                   # 3. instalador (pide sudo una vez)
# 4. cerrar sesión y volver a entrar (activa el grupo docker)
# 5. clonar tus proyectos y en cada uno:
ddev start
ddev import-db --file=~/respaldos-ddev/<fecha>/<proyecto>.sql.gz   # si hay respaldo
```

> **Consejo**: sube este repo a un remoto privado para que el paso 2 exista:
> `gh auth login && gh repo create machine-setup --private --source=. --push`

## Qué instala `setup.sh`

| Componente | Detalle |
|---|---|
| Docker Engine | repo oficial; detecta el codename y cae al LTS anterior si aún no hay paquetes |
| DDEV | repo apt oficial (`pkg.ddev.com`), independiente de la versión de Ubuntu |
| mkcert | CA local → SSL confiable en `https://*.ddev.site` |
| Node.js LTS | vía nvm (+ corepack habilita yarn/pnpm) para tooling nativo |
| PHP CLI + Composer | nativos, solo por conveniencia; las versiones "de verdad" van por proyecto en DDEV |
| GitHub CLI y VS Code | solo si faltan (PhpStorm va por JetBrains Toolbox; avisa si no está) |
| Extensiones VS Code | Xdebug, Intelephense, Laravel, Vue (Volar), EditorConfig |
| Ajustes de sistema | más watchers inotify (Vite/HMR en proyectos grandes) |

Es **idempotente**: re-córrelo cuando quieras. Toggles: `INSTALL_NATIVE_PHP=0`,
`INSTALL_GH=0`, `INSTALL_IDES=0`, `INSTALL_VSCODE_EXTS=0`
(ejemplo: `INSTALL_GH=0 bash setup.sh`). También agrega `bin/` al PATH.

## Crear un proyecto nuevo

```bash
cd ~/Developer
new-laravel mi-app            # PHP 8.4, Node 22, MySQL 8.0
new-laravel mi-app 8.3 20     # PHP 8.3, Node 20
```

Entrega: Laravel + MySQL + Mailpit + MinIO (bucket creado y Flysystem S3
instalado) + Vite/HMR + Xdebug + `.vscode/launch.json` + git inicializado.
Las URLs se imprimen al final.

## Adoptar un proyecto existente

```bash
cd mi-proyecto-clonado
adopt-laravel                 # acepta versiones: adopt-laravel 8.2 18 8.0
```

Si el proyecto ya trae `.ddev/` versionado (lo ideal), lo respeta: en ese caso
un simple `ddev start` también funciona.

## Día a día

| Acción | Comando |
|---|---|
| Levantar / apagar proyecto | `ddev start` / `ddev stop` (todos: `ddev poweroff`) |
| Artisan / Composer / npm | `ddev artisan ...` / `ddev composer ...` / `ddev npm ...` |
| Vite con HMR | `ddev npm run dev` → assets en `https://<p>.ddev.site:5173` |
| Correo capturado (Mailpit) | `ddev launch -m` → `https://<p>.ddev.site:8026` |
| Consola MinIO | `ddev minio` → `https://<p>.ddev.site:9090` (ddevminio / ddevminio) |
| MySQL CLI | `ddev mysql` (GUI externa: puerto y credenciales en `ddev describe`) |
| Xdebug on/off | `ddev xdebug on` / `ddev xdebug off` (apagado por defecto = rápido) |
| Shell dentro del contenedor | `ddev ssh` |
| Estado / URLs / puertos | `ddev describe` |
| Compartir por internet | `ddev share` |

### Cambiar versiones (por proyecto)

Edita `.ddev/config.yaml` → `php_version`, `nodejs_version` → `ddev restart`.

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

## MinIO como S3 de Laravel

`new-laravel` deja el disco `s3` apuntando a MinIO con el bucket creado:

- Interno (la app): `AWS_ENDPOINT=http://minio:10101`, path-style activado.
- Público (navegador): `https://<proyecto>.ddev.site:10101/<bucket>/...`
- Para usarlo por defecto: `FILESYSTEM_DISK=s3` en `.env`.

## Proyectos Nuxt / solo Node

Un Nuxt puro no necesita DDEV: con el Node de nvm basta (`npm run dev`).
Si quieres dominio + SSL también ahí, DDEV soporta proyectos Node
(quickstart "Node.js" en la documentación de DDEV).

## Antes de formatear

```bash
backup-projects        # BD + .env de todos los proyectos → ~/respaldos-ddev/<fecha>/
```

Y respalda también `~/.ssh`, `~/.gitconfig`, y haz push de todos tus repos
(incluido este).

## Problemas típicos

- **`permission denied ... docker.sock`** → falta re-loguear tras `setup.sh`
  (grupo docker).
- **Puerto 80/443 ocupado al `ddev start`** → `sudo systemctl disable --now apache2`
  (o el nginx local que estorbe).
- **Docker aún no publica para tu Ubuntu nuevo** → `DOCKER_CODENAME=noble bash setup.sh`.
- **Sin internet `*.ddev.site` no resuelve** → DDEV cae a `/etc/hosts`
  automáticamente (pedirá sudo al hacer `ddev start`).
- **Diagnóstico general** → `ddev debug test`.
