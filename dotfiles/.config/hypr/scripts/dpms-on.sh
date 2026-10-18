#!/bin/bash
# Re-enable DPMS on every Hyprland output.
#
# Exists because after a suspend that hypridle requested itself (`systemctl suspend` from
# its 7200s listener) hypridle's before_sleep_cmd/after_sleep_cmd do not run, so nothing
# turns the outputs back on and the machine resumes with every panel dark.
# See linux-debug/suspend-blank-screen-after-auto-suspend-2026-09-18.md.
#
# Called by dpms-on-resume.service (systemd --user, WantedBy=sleep.target), which is
# independent of hypridle firing at all.
#
# The live instance is resolved from `hyprctl instances` rather than trusted from
# $HYPRLAND_INSTANCE_SIGNATURE: that variable goes stale across a compositor restart and
# then points at a dead socket, which would make this a silent no-op.

set -uo pipefail

live=$(hyprctl -j instances 2>/dev/null | jq -r '.[0].instance // empty')
[ -n "$live" ] || { echo "dpms-on: no live Hyprland instance" >&2; exit 0; }

export HYPRLAND_INSTANCE_SIGNATURE="$live"

# hl.dsp.dpms takes a TABLE. Two spellings are wrong in different ways:
#   hyprctl dispatch dpms on            -> parse error, loud (legacy hyprlang syntax)
#   hyprctl dispatch 'hl.dsp.dpms("on")' -> returns `ok` and switches the outputs OFF
# The second was the live config until 2026-09-18. Verified with before/after readings of
# `hyprctl -j monitors | jq .[].dpmsStatus`; a success return proves nothing here.
hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'

# Restore the backlight level the 480s listener saved -- via the guarded wrapper, NOT a bare
# `brightnessctl -r`. This hook fires on EVERY resume, including resumes where nothing ever
# dimmed, so a bare `-r` replays whatever is in brightnessctl's single save cell. On
# 2026-09-19 20:51:51 that cell held the dim value itself and this line set the panel to
# 10/192000 = 0%. See linux-debug/backlight-not-restored-after-suspend-2026-09-19.md.
# The wrapper restores only when the saved level is brighter than the current one.
# Revert: command -v brightnessctl >/dev/null && brightnessctl -r
"$(dirname "$(readlink -f "$0")")/backlight-restore.sh" || true
