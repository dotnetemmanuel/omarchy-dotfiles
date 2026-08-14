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

## Bar plugins

`omarchy/.config/omarchy/plugins/` is ignored except for plugins written here.

**Ours** are tracked, and any directory under the `io.github.dotnetemmanuel.`
prefix is picked up without touching `.gitignore`. Enable each on a new machine
with `omarchy plugin enable <id>`.

`io.github.dotnetemmanuel.sysmon` puts the processor temperature in the bar and
folds out load per hardware thread (hover a bar for its share), memory,
graphics, temperatures, and the five heaviest processes labelled by working
directory so two agents in different projects are told apart. Readings come from
`/proc` and sysfs via its own `stats.sh`; right-click the bar entry for btop.

`io.github.dotnetemmanuel.media` is a clone of Omarchy's `omarchy.media` with
three changes, so `omarchy.media` stays disabled while ours is enabled:

- track progress in the popup, driven from a snapshot plus elapsed time rather
  than polling MPRIS every second
- the bar follows whatever started playing most recently; the shipped rule
  preferred the oldest, so a second source never took over
- clicking a row in the source list plays or pauses that source and pauses the
  others, instead of transferring playback

It also ignores video conferencing entirely (Slack, Discord, Zoom, Teams, Meet
and friends), matched in `Service.qml`. That filter guards the whole service, so
starting music or pressing a headphone button can never pause a call.

When cloning any built-in plugin, two things need fixing by hand afterwards: the
widget keeps pointing at the source plugin's service, which breaks the moment
that plugin is disabled, and the new id uses a bare `$USER.` prefix rather than
ours.

**Upstream clones** are not tracked, so a plugin `shell.json` references by id
has to be cloned back before the bar can show it:

```bash
git clone https://github.com/fabean/omarchy-herdr.git \
  ~/.config/omarchy/plugins/io.github.fabean.herdr
```

The directory name must match the `id` in `shell.json`, not the repo name. Note
that herdr carries a local edit here (bar font size raised to match the other
bar icons) which a fresh clone will not have.

## Samba share for the Windows VM (not a stow package)

`samba-vm-share/setup.sh` restores the share that the Windows 11 QEMU/KVM guest
mounts as `Z:`. Both files it installs live in `/etc`, so stow cannot carry them:

- `smb.conf` — the share itself, bound only to loopback and the libvirt bridge
- `virbr0.conf` — a systemd drop-in that makes Samba wait for `virbr0` to hold
  192.168.122.1 before it binds

The drop-in exists because Samba binds `virbr0` by name at startup. Without it,
Samba can start in the ~150 ms before libvirt gives the bridge its address, find
no bridge, and bind loopback only. The share then looks fine on the host while
the VM cannot reach it at all.

```bash
./samba-vm-share/setup.sh
```

The share password is not in this repo (it lives in `/etc/samba/private`). The
script tells you to set it with `sudo smbpasswd -a $USER` if it is missing.

## JetBrains themes (not stow packages)

`jetbrains-retro82-theme/` and `jetbrains-event-horizon-theme/` are theme **source
projects**, not `$HOME` config, so they carry a `.stow-local-ignore` and are
skipped by stow. Their full source (`src/`) and the built `.jar` are committed
to git, so they are safe as long as the repo is pushed to GitHub. To reinstall
them into your Toolbox-managed IDEs on a new machine:

```bash
./jetbrains-retro82-theme/build.sh
./jetbrains-event-horizon-theme/build.sh
```

Each script rebuilds the `.jar` from `src/` and copies it into every JetBrains
IDE found under `~/.local/share/JetBrains/`. Restart the IDE and pick the theme.

## What's excluded

SSH keys, GPG keys, `gh` CLI auth, Claude credentials, conversation logs, and other secrets are intentionally not in this repo. Back those up separately (password manager).
