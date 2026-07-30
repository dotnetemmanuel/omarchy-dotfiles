#!/usr/bin/env bash
# Build and install the Retro 82 JetBrains theme plugin.
# Local-use only, no marketplace metadata, no signing.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$here/src"
jar="$here/retro82-theme.jar"

cd "$src"
rm -f "$jar"
zip -qr "$jar" META-INF colors
echo "built $jar ($(wc -c < "$jar") bytes)"
unzip -l "$jar"

# Install into each Toolbox-managed IDE on disk. Android Studio is Google-vendored.
for vendor in JetBrains Google; do
  for ide_cfg in "$HOME"/.config/"$vendor"/*/; do
    ide="$(basename "$ide_cfg")"
    plugins_dir="$HOME/.local/share/$vendor/$ide"
    [ -d "$plugins_dir" ] || continue
    cp "$jar" "$plugins_dir/retro82-theme.jar"
    echo "installed $plugins_dir/retro82-theme.jar"
  done
done
