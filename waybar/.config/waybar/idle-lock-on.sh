#!/bin/bash
# Shows the idle-lock icon while hypridle is NOT running (i.e. idle locking is
# disabled). Matches the stock indicator's semantics, but rendered in red.

if pgrep -x hypridle >/dev/null; then
  echo '{"text": ""}'
else
  echo '{"text": "󱫖", "tooltip": "Idle lock disabled", "class": "active"}'
fi
