#!/usr/bin/env bash
# Build and install the Aether JetBrains theme plugin.
# Local-use only — no marketplace metadata, no signing.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$here/src"
jar="$here/aether-theme.jar"

cd "$src"
rm -f "$jar"
zip -qr "$jar" META-INF colors
echo "built $jar ($(wc -c < "$jar") bytes)"
unzip -l "$jar"

# Install into each Toolbox-managed IDE on disk.
for ide_cfg in "$HOME"/.config/JetBrains/*/; do
  ide="$(basename "$ide_cfg")"
  plugins_dir="$HOME/.local/share/JetBrains/$ide"
  [ -d "$plugins_dir" ] || continue
  cp "$jar" "$plugins_dir/aether-theme.jar"
  echo "installed $plugins_dir/aether-theme.jar"
done
