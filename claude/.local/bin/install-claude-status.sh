#!/usr/bin/env bash
# Installer for the Claude Code -> Waybar traffic light.
#
# Run it from the directory that holds the claude-status* scripts:
#     ./install-claude-status.sh
#
# It is idempotent (safe to re-run) and backs up every file it edits. Env knobs:
#     BIN_DIR=~/.local/bin          where to install the scripts
#     WAYBAR_DIR=~/.config/waybar   waybar config dir
#     SETTINGS=~/.claude/settings.json
#     SIDE=modules-right            which bar array to add the module to
#     NO_CONFIG=1                   skip touching config.jsonc (print snippet only)
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
WAYBAR_DIR="${WAYBAR_DIR:-$HOME/.config/waybar}"
SETTINGS="${SETTINGS:-$HOME/.claude/settings.json}"
SIDE="${SIDE:-modules-right}"
HOOK="$BIN_DIR/claude-status-hook"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
info() { printf '  \033[34m·\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\033[31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
bak()  { [ -f "$1" ] && cp -f "$1" "$1.bak.$(date +%s)"; }

echo "Installing Claude Code waybar module…"

# --- 1. dependencies --------------------------------------------------------
command -v jq     >/dev/null || die "jq is required (pacman -S jq)"
command -v waybar >/dev/null || warn "waybar not found on PATH"
for opt in hyprctl tmux walker fuzzel wofi rofi tofi dmenu; do
  command -v "$opt" >/dev/null && { info "optional: $opt found"; break; }
done

# --- 2. scripts -------------------------------------------------------------
mkdir -p "$BIN_DIR"
for f in claude-status claude-status-hook claude-status-pick; do
  [ -f "$SRC/$f" ] || die "missing $SRC/$f (run from the scripts dir)"
  install -m 0755 "$SRC/$f" "$BIN_DIR/$f"
done
ok "scripts -> $BIN_DIR"

# --- 3. hooks -> settings.json (merge, idempotent) --------------------------
mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
bak "$SETTINGS"
tmp="$(mktemp)"
jq --arg h "$HOOK" '
  ((.hooks // {}) | [ .[]?[]?.hooks[]?.command ] | any(test("claude-status-hook"))) as $have
  | if $have then .
    else .hooks = ((.hooks // {})
      | .SessionStart    = ((.SessionStart    // []) + [{"hooks":[{"type":"command","command":($h+" start")}]}])
      | .UserPromptSubmit = ((.UserPromptSubmit // []) + [{"hooks":[{"type":"command","command":($h+" prompt")}]}])
      | .PreToolUse      = ((.PreToolUse      // []) + [{"matcher":"","hooks":[{"type":"command","command":($h+" tool")}]}])
      | .Notification    = ((.Notification    // []) + [{"matcher":"","hooks":[{"type":"command","command":($h+" notify")}]}])
      | .Stop            = ((.Stop            // []) + [{"hooks":[{"type":"command","command":($h+" stop")}]}])
      | .SessionEnd      = ((.SessionEnd      // []) + [{"hooks":[{"type":"command","command":($h+" end")}]}]))
    end
' "$SETTINGS" > "$tmp" || die "jq failed merging hooks"
jq -e . "$tmp" >/dev/null || die "merged settings.json is invalid"
mv "$tmp" "$SETTINGS"
ok "hooks -> $SETTINGS"

# --- 4. CSS -> style.css (append if absent) ---------------------------------
css="$WAYBAR_DIR/style.css"
mkdir -p "$WAYBAR_DIR"; touch "$css"
if grep -q '#custom-claude' "$css"; then
  info "style.css already has #custom-claude — left as-is"
else
  bak "$css"
  cat >> "$css" <<'CSS'

/* Claude Code traffic light (self-contained: no theme vars needed) */
#custom-claude { padding: 0 8px; }
#custom-claude.working { animation: claude-pulse 1.5s ease-in-out infinite; }
#custom-claude.waiting { animation: claude-halo  1.7s ease-in-out infinite; }
@keyframes claude-pulse { 0%{opacity:1;} 50%{opacity:.45;} 100%{opacity:1;} }
@keyframes claude-halo {
  0%   { text-shadow: 0 0 2px rgba(250,183,149,.35); }
  50%  { text-shadow: 0 0 9px #fab795, 0 0 4px #fab795; }
  100% { text-shadow: 0 0 2px rgba(250,183,149,.35); }
}
CSS
  ok "css -> $css"
fi

# --- 5. module -> config.jsonc ----------------------------------------------
cfg="$WAYBAR_DIR/config.jsonc"
module_def="  \"custom/claude\": {
    \"exec\": \"$BIN_DIR/claude-status\",
    \"return-type\": \"json\",
    \"interval\": 2,
    \"signal\": 10,
    \"tooltip\": true,
    \"on-click\": \"$BIN_DIR/claude-status-pick\"
  },"

if [ "${NO_CONFIG:-0}" = 1 ] || [ ! -f "$cfg" ]; then
  warn "Not editing config.jsonc automatically. Add this module:"
  printf '%s\n' "$module_def"
  warn "…and add \"custom/claude\" to your \"$SIDE\" array."
elif grep -q '"custom/claude"' "$cfg"; then
  info "config.jsonc already references custom/claude — left as-is"
else
  bak "$cfg"
  # insert the module definition just after the opening brace of the root object
  awk -v def="$module_def" '
    !done && /{/ { print; print def; done=1; next } { print }
  ' "$cfg" > "$cfg.tmp"
  # add "custom/claude" into the chosen modules array
  awk -v side="\"$SIDE\"" '
    $0 ~ side "[[:space:]]*:[[:space:]]*\\[" { print; print "    \"custom/claude\","; next } { print }
  ' "$cfg.tmp" > "$cfg.tmp2"
  mv "$cfg.tmp2" "$cfg"; rm -f "$cfg.tmp"
  # validate: a bad config makes waybar log a [error] line; a good one just runs
  # until timeout. Restore the backup if we see a real parse error.
  if command -v waybar >/dev/null; then
    errf="$(mktemp)"
    timeout 2 waybar -c "$cfg" -s "$css" >/dev/null 2>"$errf" || true
    if grep -q '\[error\]' "$errf"; then
      last_bak="$(ls -t "$cfg".bak.* 2>/dev/null | head -1)"
      [ -n "$last_bak" ] && cp -f "$last_bak" "$cfg"
      warn "config.jsonc parse failed — restored backup. Add the module manually:"
      printf '%s\n' "$module_def"
      warn "…and add \"custom/claude\" to your \"$SIDE\" array."
    else
      ok "module -> $cfg (in $SIDE)"
    fi
    rm -f "$errf"
  else
    ok "module -> $cfg (in $SIDE; install waybar to validate)"
  fi
fi

echo
ok "Done. Restart waybar:  omarchy restart waybar   (or: pkill waybar; waybar &)"
info "Open a new Claude session to see it light up."
