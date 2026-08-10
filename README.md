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
git clone git@github.com:dotnetemmanuel/omarchy-dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` installs stow if needed and symlinks every package into `$HOME`.
By default stow refuses to overwrite an existing file. Since a fresh Omarchy
ships its own default configs, those will conflict. Run `./install.sh --adopt`
to absorb the existing files into the repo instead of aborting, then check
`git diff` to see what changed and discard anything you did not want.

The clone location does not have to be `~/dotfiles` anymore (paths are resolved
relative to `$HOME` via stow, not hardcoded).

## Packages

Desktop / WM: `hypr`, `waybar`, `walker`, `mako`, `swayosd`, `omarchy`, `omarchy-extras`, `hyprdynamicmonitors`, `hyprland-preview-share-picker`, `elephant`, `fcitx5`, `autostart`, `fontconfig`, `environment.d`, `imv`, `wireplumber`

Terminals / shell: `alacritty`, `ghostty`, `kitty`, `starship`, `shell`, `tmux`

Tools: `btop`, `fastfetch`, `lazygit`, `lazydocker`, `git`

Editors: `nvim`, `zed`

Claude Code: `claude` (cherry-picked — settings, keybindings, skills, memory only; no auth, sessions, or conversation logs)

## QGIS MCP (not a stow package)

`qgis-mcp/setup.sh` reinstalls the QGIS MCP integration, which lives in three
places outside this repo: the plugin in the QGIS profile, the profile settings
that enable it, and the server registration in `~/.claude.json`. None of those
are backed up here, so run the script on a new machine (with QGIS closed):

```bash
./qgis-mcp/setup.sh
```

It pulls the plugin from upstream, so re-running it also updates the plugin.
Set `QGIS_PROFILE` to target a profile other than `default`.

## JetBrains themes (not stow packages)

`jetbrains-retro82-theme/` and `jetbrains-aether-theme/` are theme **source
projects**, not `$HOME` config, so they carry a `.stow-local-ignore` and are
skipped by stow. Their full source (`src/`) and the built `.jar` are committed
to git, so they are safe as long as the repo is pushed to GitHub. To reinstall
them into your Toolbox-managed IDEs on a new machine:

```bash
./jetbrains-retro82-theme/build.sh
./jetbrains-aether-theme/build.sh
```

Each script rebuilds the `.jar` from `src/` and copies it into every JetBrains
IDE found under `~/.local/share/JetBrains/`. Restart the IDE and pick the theme.

## What's excluded

SSH keys, GPG keys, `gh` CLI auth, Claude credentials, conversation logs, and other secrets are intentionally not in this repo. Back those up separately (password manager).
