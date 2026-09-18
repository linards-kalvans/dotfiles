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

# Restore the backlight level the 480s listener saved with `brightnessctl -s`.
command -v brightnessctl >/dev/null && brightnessctl -r
