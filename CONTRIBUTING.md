# Contribuir

Gracias por mejorar el kit. Tres cosas antes de abrir un PR:

## 1. Corre las pruebas

```bash
bash tests/run.sh          # todas (no tocan tu sistema: usan ddev/docker simulados)
bash tests/run.sh vite     # solo un archivo: tests/vite.sh
```

Las pruebas de los instaladores no instalan nada: ejercitan la lógica de
detección de distro y los helpers con `ddev` y `docker` falsos. La instalación
completa se prueba en CI dentro de contenedores de Debian y Ubuntu.

## 2. Pasa el linter

```bash
shellcheck -x setup.sh setup-*.sh bin/* lib/*.sh tests/*.sh
shfmt -i 2 -ci -d setup.sh setup-*.sh bin/* lib/*.sh tests/*.sh
```

En Debian/Ubuntu: `sudo apt install shellcheck shfmt`. En macOS:
`brew install shellcheck shfmt`.

## 3. Estilo

- Los scripts hablan **español, de tú**, y explican el porqué en los comentarios:
  el kit lo usa gente que llega por primera vez a DDEV.
- Bash portable: los `bin/` corren también con el bash 3.2 de macOS (sin
  `mapfile`, sin `${var,,}`, sin `declare -A`). Nada de `sed -i` en los `bin/`
  (GNU y BSD difieren); en `setup-debian.sh` sí, porque es solo Linux.
- Lo compartido vive en `lib/`; si copias una función entre dos scripts, es que
  va ahí.
- Commits en inglés con prefijo convencional (`feat:`, `fix:`, `docs:`,
  `chore:`), como el historial.
- Anota los cambios visibles en `CHANGELOG.md`, sección *Sin publicar*.
