# omarchy-dotfiles

Personal dotfiles for an Omarchy (Arch + Hyprland) setup, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Layout

Each top-level directory is a stow package. Files inside mirror their location relative to `$HOME`.

```
hypr/.config/hypr/      -> ~/.config/hypr/
shell/.zshrc            -> ~/.zshrc
claude/.claude/skills/  -> ~/.claude/skills/
```

## Bootstrap on a new machine

```bash
sudo pacman -S --needed stow
git clone git@github.com:dotnetemmanuel/omarchy-dotfiles.git ~/dotfiles
cd ~/dotfiles
stow -t ~ */
```

Stow will refuse to overwrite existing files — if a target already exists, back it up or delete it first, then re-run.

## Packages

Desktop / WM: `hypr`, `waybar`, `walker`, `mako`, `swayosd`, `omarchy`, `omarchy-extras`, `hyprdynamicmonitors`, `hyprland-preview-share-picker`, `elephant`, `fcitx5`, `autostart`, `fontconfig`, `environment.d`, `imv`

Terminals / shell: `alacritty`, `ghostty`, `kitty`, `starship`, `shell`, `tmux`

Tools: `btop`, `fastfetch`, `lazygit`, `lazydocker`, `git`

Editors: `nvim`, `zed`

Claude Code: `claude` (cherry-picked — settings, keybindings, skills, memory only; no auth, sessions, or conversation logs)

## What's excluded

SSH keys, GPG keys, `gh` CLI auth, Claude credentials, conversation logs, and other secrets are intentionally not in this repo. Back those up separately (password manager).
