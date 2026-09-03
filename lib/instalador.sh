#!/usr/bin/env bash
# lib/instalador.sh — pasos que comparten los instaladores de Linux y macOS.
# Requiere lib/comun.sh cargado antes.

instalar_node_nvm() {
  paso "Node.js LTS (vía nvm) + npm + corepack"
  export NVM_DIR="$HOME/.nvm"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    local tag
    tag=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name // empty' || true)
    if [ -z "$tag" ]; then tag="v0.40.3"; fi # si la API de GitHub no responde (límite de peticiones)
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${tag}/install.sh" | bash
  fi
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm alias default 'lts/*' >/dev/null
  corepack enable >/dev/null 2>&1 || true # yarn y pnpm bajo demanda
  ok "node $(node -v) / npm $(npm -v)"
}

instalar_extensiones_vscode() { # instalar_extensiones_vscode <ruta-al-comando-code>
  paso "Extensiones VS Code (PHP, Xdebug, Laravel, Vue)"
  local ext
  for ext in xdebug.php-debug bmewburn.vscode-intelephense-client laravel.vscode-laravel Vue.volar EditorConfig.EditorConfig; do
    if "$1" --install-extension "$ext" >/dev/null 2>&1; then ok "$ext"; else aviso "no pude instalar $ext"; fi
  done
}

revisar_git() {
  paso "Git"
  git config --global init.defaultBranch main
  if [ -z "$(git config --global user.name 2>/dev/null || true)" ]; then
    aviso "Falta tu identidad git:  git config --global user.name 'Tu Nombre' && git config --global user.email 'tu@correo'"
  else
    ok "identidad git: $(git config --global user.name) <$(git config --global user.email)>"
  fi
  if ! ls "$HOME"/.ssh/id_* >/dev/null 2>&1; then
    aviso "Sin llaves SSH: restaura tu respaldo o crea una:  ssh-keygen -t ed25519 -C 'tu@correo'"
  fi
}

# Los helpers de bin/ (new-laravel, adopt-laravel, backup-projects…) se enlazan en ~/.local/bin:
# funciona con cualquier shell sin tocar el PATH. Son enlaces a la ruta del clon: si mueves
# la carpeta del kit, vuelve a correr setup.sh para re-enlazarlos (kit-doctor lo avisa).
instalar_helpers() { # instalar_helpers <raiz-del-kit> <archivo-rc-de-tu-shell>
  paso "Helpers del kit (new-laravel, adopt-laravel, backup-projects, restore-projects, kit-doctor)"
  local raiz=$1 rc=$2 h
  mkdir -p "$HOME/.local/bin"
  for h in "$raiz"/bin/*; do
    ln -sfn "$h" "$HOME/.local/bin/$(basename "$h")"
  done
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ok "enlazados en ~/.local/bin (ya está en tu PATH)" ;;
    *)
      # Debian y Ubuntu lo agregan al iniciar sesión si la carpeta existe (~/.profile)
      if grep -qsF '.local/bin' "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bashrc" 2>/dev/null; then
        ok "enlazados en ~/.local/bin (entra al PATH al abrir una terminal nueva o al volver a iniciar sesión)"
      else
        # shellcheck disable=SC2016 # se escribe literal, lo expande la shell al iniciar
        printf '\n# helpers laravel-ddev-kit\nexport PATH="$HOME/.local/bin:$PATH"\n' >>"$rc"
        ok "enlazados en ~/.local/bin; agregué ~/.local/bin al PATH en ${rc} (abre una terminal nueva)"
      fi
      ;;
  esac
}
