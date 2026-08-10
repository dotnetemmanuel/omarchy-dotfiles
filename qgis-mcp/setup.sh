#!/usr/bin/env bash
# Reinstalls the QGIS MCP integration on a fresh machine: the QGIS plugin, the
# profile settings that enable it, and the server registration for Claude Code.
# Idempotent. Re-run it to pull the latest plugin from upstream.
set -euo pipefail

archive_url="https://github.com/nkarasiak/qgis-mcp/archive/refs/heads/main.zip"
profile="${QGIS_PROFILE:-default}"

if pgrep -x qgis >/dev/null 2>&1; then
  echo "QGIS is running. Close it first: it rewrites its settings file on exit and would undo this." >&2
  exit 1
fi

for cmd in curl unzip python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd not found, install it first" >&2; exit 1; }
done

if ! command -v uvx >/dev/null 2>&1; then
  echo "uvx not found, installing uv..."
  sudo pacman -S --needed --noconfirm uv
fi

version=""
for v in 4 3; do
  if [ -d "$HOME/.local/share/QGIS/QGIS$v/profiles/$profile" ]; then
    version="$v"
    break
  fi
done
if [ -z "$version" ]; then
  version=4
  echo "no existing QGIS profile named '$profile', creating one under QGIS4"
fi

profile_dir="$HOME/.local/share/QGIS/QGIS$version/profiles/$profile"
plugins_dir="$profile_dir/python/plugins"
ini="$profile_dir/QGIS/QGIS$version.ini"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "downloading plugin..."
curl -fsSL "$archive_url" -o "$tmp/qgis-mcp.zip"
unzip -q "$tmp/qgis-mcp.zip" -d "$tmp"
src="$tmp/qgis-mcp-main/qgis_mcp_plugin"
[ -d "$src" ] || { echo "upstream archive layout changed, no qgis_mcp_plugin/ inside" >&2; exit 1; }

mkdir -p "$plugins_dir"
rm -rf "$plugins_dir/qgis_mcp_plugin"
cp -r "$src" "$plugins_dir/qgis_mcp_plugin"
echo "installed plugin: $plugins_dir/qgis_mcp_plugin"

python3 - "$ini" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []


def ensure(section, key, value):
    header = f"[{section}]"
    entry = f"{key}={value}"
    start = next((i for i, line in enumerate(lines) if line.strip() == header), None)

    if start is None:
        if lines and lines[-1].strip():
            lines.append("")
        lines.extend([header, entry, ""])
        return True

    end = start + 1
    while end < len(lines) and not lines[end].startswith("["):
        if lines[end].split("=", 1)[0].strip() == key:
            if lines[end] == entry:
                return False
            lines[end] = entry
            return True
        end += 1

    while end > start + 1 and not lines[end - 1].strip():
        end -= 1
    lines.insert(end, entry)
    return True


changed = [ensure("PythonPlugins", "qgis_mcp_plugin", "true"), ensure("qgis_mcp", "autostart", "true")]
if any(changed):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"enabled plugin in {path}")
else:
    print(f"already enabled in {path}")
PY

if command -v claude >/dev/null 2>&1; then
  claude mcp remove -s user qgis >/dev/null 2>&1 || true
  claude mcp add -s user qgis -- uvx --from "$archive_url" qgis-mcp-server
else
  echo "claude CLI not found, register the server later with:"
  echo "  claude mcp add -s user qgis -- uvx --from $archive_url qgis-mcp-server"
fi

echo
echo "done. Start QGIS, then check the connection with: claude mcp list"
