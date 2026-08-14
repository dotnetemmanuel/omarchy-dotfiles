#!/usr/bin/env bash
# Reinstalls the Samba share the Windows 11 VM mounts as Z:. Both files live in
# /etc, so stow cannot carry them. Idempotent. Safe to re-run.
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
share="$HOME/mpd-share"

if ! pacman -Q samba >/dev/null 2>&1; then
  echo "samba not found, installing..."
  sudo pacman -S --needed --noconfirm samba
fi

mkdir -p "$share"

if [ -f /etc/samba/smb.conf ] && ! cmp -s "$dir/smb.conf" /etc/samba/smb.conf; then
  sudo cp -a /etc/samba/smb.conf /etc/samba/smb.conf.bak
  echo "existing smb.conf differed, saved as /etc/samba/smb.conf.bak"
fi

sudo install -Dm644 "$dir/smb.conf" /etc/samba/smb.conf
sudo install -Dm644 "$dir/virbr0.conf" /etc/systemd/system/smb.service.d/virbr0.conf
sudo systemctl daemon-reload
sudo systemctl enable --now smb.service
sudo systemctl restart smb.service

echo
if ! sudo pdbedit -L 2>/dev/null | grep -q "^$USER:"; then
  echo "No Samba password set for $USER yet. The VM cannot log in until you run:"
  echo "  sudo smbpasswd -a $USER"
  echo
fi
echo "Share path: $share"
echo "Reachable from the VM as: \\\\192.168.122.1\\mpd-share"
echo "Verify Samba is on the bridge, not just loopback:"
echo "  ss -tln | grep 192.168.122.1"
