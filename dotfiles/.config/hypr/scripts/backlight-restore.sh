#!/bin/bash
# Restore the backlight saved by backlight-dim.sh -- but never darken the panel.
#
# A bare `brightnessctl -r` replays whatever is in the single save cell, with no way to tell
# a fresh pre-dim level from a stale or poisoned one. Called from a resume hook it runs on
# EVERY resume, including resumes where nothing ever dimmed, so a stale cell silently sets
# the panel to an old (or near-zero) level.
# See linux-debug/backlight-not-restored-after-suspend-2026-09-19.md.
#
# This wrapper restores only when the saved level is BRIGHTER than the current one. Undoing
# a dim is always an increase, so the guard cannot block a legitimate restore -- but it makes
# a stale or poisoned cell harmless.

set -uo pipefail

command -v brightnessctl >/dev/null || exit 0

cur=$(brightnessctl -m get) || exit 0
dev=$(brightnessctl -m | cut -d, -f1)
slot="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/brightnessctl/backlight/${dev}"

[ -r "$slot" ] || exit 0
saved=$(tr -cd '0-9' < "$slot")
[ -n "$saved" ] || exit 0

if [ "$saved" -gt "$cur" ]; then
    brightnessctl -r
fi
