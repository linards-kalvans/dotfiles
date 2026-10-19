#!/usr/bin/env bash
# __        __    _ _                            ____       _
# \ \      / /_ _| | |_ __   __ _ _ __   ___ _ _/ ___|  ___| |_
#  \ \ /\ / / _` | | | '_ \ / _` | '_ \ / _ \ '_\___ \ / _ \ __|
#   \ V  V / (_| | | | |_) | (_| | |_) |  __/ |  ___) |  __/ |_
#    \_/\_/ \__,_|_|_| .__/ \__,_| .__/ \___|_| |____/ \___|\__|
#                    |_|         |_|
#
# Set one wallpaper and run the full ML4W retheme.  Usage: wallpaper-set.sh <image>
#
# Normally ML4W paints the wallpaper with `waypaper`, whose post_command is
# scripts/wallpaper.sh (matugen, waybar + nwg-dock relaunch, and the two hyprlock
# images).  waypaper 2.9-1 is currently UNIMPORTABLE on this host: its deps
# python-screeninfo and python-imageio-ffmpeg are AUR builds still installed under
# /usr/lib/python3.13/site-packages while system python is 3.14, so every call dies
# with `ModuleNotFoundError: No module named 'screeninfo'`.  That is what left the
# desktop black -- swww had no image to show and its per-output cache under
# ~/.cache/swww/ went stale back in April.
#
# So: use waypaper when it actually imports, and otherwise do exactly what it would
# have done -- `swww img` with waypaper's own transition settings, then wallpaper.sh
# by hand.  Rebuilding those two AUR packages restores the first branch with no
# change here.

set -u

readonly WALLPAPER="${1:?usage: wallpaper-set.sh <image>}"
readonly ML4W_CACHE="$HOME/.cache/ml4w/hyprland-dotfiles"

export PATH="$PATH:$HOME/.local/bin"

[ -f "$WALLPAPER" ] || { echo ":: No such wallpaper: $WALLPAPER"; exit 1; }

if waypaper --version >/dev/null 2>&1; then
    # waypaper is healthy; its post_command hook runs wallpaper.sh for us.
    echo ":: Setting wallpaper via waypaper"
    waypaper --wallpaper "$WALLPAPER"
    exit $?
fi

echo ":: waypaper is broken, setting wallpaper via swww directly"

# Transition values mirror [Settings] in ~/.config/waypaper/config.ini, so the
# fallback looks identical to the healthy path.  waypaper's `fill = fill` is
# swww's `--resize crop`.
swww img "$WALLPAPER" \
    --resize crop \
    --transition-type any \
    --transition-step 90 \
    --transition-angle 0 \
    --transition-duration 2 \
    --transition-fps 60 || exit 1

# Keep waypaper's own record straight, so the GUI picker opens on the right image
# once it is repaired.
sed -i "s|^wallpaper = .*|wallpaper = $WALLPAPER|" "$HOME/.config/waypaper/config.ini"

# ML4W's retheme engine: matugen, waybar, nwg-dock, blurred_wallpaper.png and
# square_wallpaper.png (both read by hyprlock.conf).
"$HOME/.config/hypr/scripts/wallpaper.sh" "$WALLPAPER"

echo ":: Wallpaper set: $WALLPAPER"
