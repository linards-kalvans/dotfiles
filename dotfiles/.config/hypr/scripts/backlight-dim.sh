#!/bin/bash
# Dim the internal panel for hypridle's idle timeout, without poisoning brightnessctl's
# save slot.
#
# brightnessctl keeps ONE save cell per device, at
# $XDG_RUNTIME_DIR/brightnessctl/<class>/<device>. `-s` writes the CURRENT level into it
# *before* applying the operation, and `-r` never clears it (upstream process_device()).
# So `brightnessctl -s set <dim>` run while the panel is already at <dim> stores <dim>, and
# every later `-r` restores to near-black -- permanently, because raising the backlight by
# keybind does not rewrite the cell. That is exactly what happened on 2026-09-18 22:12:22.
# See linux-debug/backlight-not-restored-after-suspend-2026-09-19.md.
#
# Fix: only pass `-s` when there is actually a brighter level worth saving.

set -uo pipefail

command -v brightnessctl >/dev/null || exit 0

cur=$(brightnessctl -m get) || exit 0
max=$(brightnessctl -m max) || exit 0

# 10% of max. The previous target was a raw 10 of 192000 = 0.005%, visually identical to
# DPMS-off -- which is why a latched dim went unnoticed for a day. Revert to `set 10` here
# to restore the old behaviour.
tgt=$((max / 10))
[ "$tgt" -gt 0 ] || tgt=1

if [ "$cur" -gt "$tgt" ]; then
    brightnessctl -s set "$tgt"      # brighter than the target: safe to save
else
    brightnessctl set "$tgt"         # already at or below: saving would latch the dim value
fi
