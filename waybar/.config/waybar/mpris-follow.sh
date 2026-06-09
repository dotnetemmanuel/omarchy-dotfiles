#!/bin/bash
# Live now-playing for Waybar, event-driven via `playerctl --follow`.
#
# Why this exists: Waybar's built-in `mpris` module re-renders on every D-Bus
# property change, and Spotify emits position updates ~once per second. That
# pegged Waybar's main thread at ~40-55% CPU. `playerctl --follow metadata`
# only emits on track / play-pause changes, so the bar stays idle between songs.
#
# markup_escape handles &, <, >, " and ' — which keeps the emitted text both
# Pango-safe and JSON-safe (raw double-quotes become &quot;).
exec playerctl --follow \
  --format '{"alt":"{{lc(status)}}","class":"{{lc(status)}}","text":"{{markup_escape(artist)}} - {{markup_escape(title)}}","tooltip":"{{markup_escape(title)}} — {{markup_escape(artist)}}"}' \
  metadata 2>/dev/null
