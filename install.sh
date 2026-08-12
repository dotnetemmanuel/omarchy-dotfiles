#!/usr/bin/env bash
# Idempotent bootstrap for these dotfiles. Safe to re-run any time.
# Installs GNU Stow if missing, then symlinks every stow package into $HOME.
# The jetbrains-*-theme dirs carry a .stow-local-ignore so stow treats them as
# no-ops (they are build source, not $HOME config).
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo"

if ! command -v stow >/dev/null 2>&1; then
  echo "stow not found, installing..."
  sudo pacman -S --needed --noconfirm stow
fi

# --adopt makes stow pull any pre-existing target file into the repo instead of
# aborting on conflict (Omarchy ships default configs). Review git diff after.
mode="${1:-}"
adopt=""
if [ "$mode" = "--adopt" ]; then
  adopt="--adopt"
  echo "running with --adopt: existing files will be absorbed into the repo (check git diff afterward)"
fi

# Stow every top-level dir. Non-package dirs (jetbrains themes) self-ignore.
# shellcheck disable=SC2035
stow -R $adopt -t "$HOME" -v */

echo
echo "done. If you used --adopt, run: git diff   to review what got absorbed."
echo "JetBrains themes are not stowed. Rebuild/install them with:"
echo "  ./jetbrains-retro82-theme/build.sh"
echo "  ./jetbrains-event-horizon-theme/build.sh"
