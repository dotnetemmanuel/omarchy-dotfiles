# Claude Code — Waybar traffic light

A Waybar module that shows, at a glance, what your running Claude Code sessions
are doing: a sunburst + `claude` + three dots (🔴 working / 🟡 waiting for input /
🟢 idle) and a `(N)` live session count. Click it for a launcher list of every
session that jumps you straight to it (handles tmux).

It is **not** tied to this dotfiles setup or the Omarchy theme — see *Portability*
below. The only hard requirements are `bash`, `jq`, and a Waybar.

## How it works

- **Existence** comes from the OS: the exec lists running `claude` processes
  (`pgrep -x claude`), skipping nested ones (subagents / `claude -p`) and
  suspended/zombie ones. So every real session always shows, even before it has
  fired a hook; the count updates on create/terminate within the poll interval.
- **State + window** come from Claude Code hooks (`settings.json`) that write a
  tiny per-session file and signal Waybar (`SIGRTMIN+10`) for instant updates.
- **Click** opens a dmenu launcher of the sessions; selecting one focuses its
  terminal window (Hyprland) and, if it runs in tmux, `switch-client`s to its pane.

## Files (all in this dir)

| File | Role |
|------|------|
| `claude-status`      | Waybar `exec` — emits the JSON for the module |
| `claude-status-hook` | Claude Code hook handler — records state, signals Waybar |
| `claude-status-pick` | `on-click` — dmenu session picker + focus |

## Dependencies

- **Required:** `bash`, `jq`, Waybar.
- **Click-to-focus:** `hyprctl` (Hyprland). On other compositors focus is skipped
  but everything else works.
- **tmux jump:** `tmux` (only used when a session runs inside it).
- **Picker UI:** any of `walker`, `fuzzel`, `wofi`, `rofi`, `tofi`, `dmenu`
  (auto-detected; override with `CLAUDE_PICK_MENU="mymenu --dmenu ..."`).
- **Glyph:** a Nerd Font for the sunburst (optional — set `LOGO_GLYPH=""` in
  `claude-status` to drop it, or change the `` codepoint).

## Quick install (automated)

From the directory holding these scripts:

```bash
./install-claude-status.sh
```

It is idempotent and backs up every file it edits. It copies the scripts to
`~/.local/bin`, merges the hooks into `~/.claude/settings.json` (preserving any
existing hooks), appends the CSS, and inserts the module into `config.jsonc`
(adding `custom/claude` to `modules-right` by default), validating the result
and restoring the backup if waybar can't parse it. Then `omarchy restart waybar`.

Knobs: `BIN_DIR=`, `WAYBAR_DIR=`, `SETTINGS=`, `SIDE=modules-left`,
`NO_CONFIG=1` (print the module snippet instead of editing `config.jsonc`).

## Manual install on any Waybar

1. **Scripts** — copy the three `claude-status*` files onto `PATH`
   (e.g. `~/.local/bin`) and `chmod +x` them. Note the absolute path you used.

2. **Module** — in `~/.config/waybar/config.jsonc`:
   ```jsonc
   "custom/claude": {
     "exec": "/ABS/PATH/claude-status",
     "return-type": "json",
     "interval": 2,
     "signal": 10,
     "tooltip": true,
     "on-click": "/ABS/PATH/claude-status-pick"
   }
   ```
   Add `"custom/claude"` to one of your `modules-*` arrays.

3. **Style** — in `~/.config/waybar/style.css` (self-contained, no theme vars):
   ```css
   #custom-claude { padding: 0 8px; }
   #custom-claude.working { animation: claude-pulse 1.5s ease-in-out infinite; }
   #custom-claude.waiting { animation: claude-halo  1.7s ease-in-out infinite; }
   @keyframes claude-pulse { 0%{opacity:1;} 50%{opacity:.45;} 100%{opacity:1;} }
   @keyframes claude-halo {
     0%   { text-shadow: 0 0 2px rgba(250,183,149,.35); }
     50%  { text-shadow: 0 0 9px #fab795, 0 0 4px #fab795; }
     100% { text-shadow: 0 0 2px rgba(250,183,149,.35); }
   }
   ```

4. **Hooks** — merge into `~/.claude/settings.json` (`$ABS` = the path from step 1):
   ```json
   "hooks": {
     "SessionStart":     [ { "hooks": [ { "type": "command", "command": "$ABS/claude-status-hook start"  } ] } ],
     "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "$ABS/claude-status-hook prompt" } ] } ],
     "PreToolUse":       [ { "matcher": "", "hooks": [ { "type": "command", "command": "$ABS/claude-status-hook tool" } ] } ],
     "Notification":     [ { "matcher": "", "hooks": [ { "type": "command", "command": "$ABS/claude-status-hook notify" } ] } ],
     "Stop":             [ { "hooks": [ { "type": "command", "command": "$ABS/claude-status-hook stop" } ] } ],
     "SessionEnd":       [ { "hooks": [ { "type": "command", "command": "$ABS/claude-status-hook end" } ] } ]
   }
   ```

5. Restart Waybar. New Claude sessions appear automatically; existing ones appear
   on their next hook event (or restart them).

## Customization

- **Colors / light themes** — with an Omarchy theme the palette is read from
  `colors.toml`, so it adapts to **light or dark** themes automatically. Without
  Omarchy, the dots use universal traffic-light fallbacks (red/amber/green) that
  stay legible on any background, and the logo + `(N)` count inherit the bar's own
  text colour (so they're never invisible on a light bar). To hard-set colours,
  edit the `RED/GRN/YEL/ACC/OFF/FG` defaults near the top of `claude-status`.
- **Glyph** — change `LOGO_GLYPH` in `claude-status` (`` asterisk by default;
  `` sun, `` north-star, etc.).
- **Picker launcher** — `export CLAUDE_PICK_MENU="fuzzel --dmenu"` (etc.).
- **Debug** — `touch "$XDG_RUNTIME_DIR/claude-code-status/.debug"` to log hook
  events to `debug.log` in that dir; delete the `.debug` flag to stop.

## Notes / limitations

- The `signal` number (10 → `SIGRTMIN+10`) must be unused by your other modules.
- Window focus on non-Hyprland compositors isn't implemented (state still works).
- Terminal *tabs* (non-tmux) can't be individually focused; tmux windows/panes can.
