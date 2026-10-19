#!/usr/bin/env bash
# __        __    _ _                             ____              _
# \ \      / /_ _| | |_ __   __ _ _ __   ___ _ __| __ )  ___   ___ | |_
#  \ \ /\ / / _` | | | '_ \ / _` | '_ \ / _ \ '__|  _ \ / _ \ / _ \| __|
#   \ V  V / (_| | | | |_) | (_| | |_) |  __/ |  | |_) | (_) | (_) | |_
#    \_/\_/ \__,_|_|_| .__/ \__,_| .__/ \___|_|  |____/ \___/ \___/ \__|
#                    |_|         |_|
#
# Wallpaper bring-up and rotation, run once at Hyprland startup.
#
# Replaces ML4W's stock autostart pair:
#     exec-once = swww-daemon
#     exec-once = ~/.config/hypr/scripts/wallpaper-restore.sh
# Those two race.  swww-daemon is spawned ~2s into compositor startup and exits if
# it cannot bind the Wayland outputs yet; wallpaper-restore.sh then calls waypaper
# against a socket that is not there and fails silently.  Nothing logs either half:
# the daemon writes to a stderr Hyprland discards.  This script waits for the daemon
# to actually ANSWER before restoring, so a slow output bring-up delays the wallpaper
# instead of losing it.
#
# It also owns the rotation loop, in place of ML4W's wallpaper-automation.sh.  That
# script cannot be used from an autostart entry: it is a TOGGLE keyed on a flag file
# under ~/.cache, which survives reboot, so a session that ended with rotation on
# comes back up, sees the flag, and switches rotation OFF.  The interval still comes
# from ML4W's own settings file, so the ML4W Settings app remains the place to change
# it.
#
# Idempotent -- safe to re-run by hand to repair a live session.
#
# Stop rotation for this session:   kill $(cat ~/.cache/ml4w/hyprland-dotfiles/wallpaper-boot.lock)
# Revert entirely: drop the exec-once / hl.exec_cmd line that calls this
# (conf/custom.conf and lua/autostart.lua); ML4W's own two entries still stand.

set -u

readonly DAEMON_TIMEOUT=30
readonly ML4W_CACHE="$HOME/.cache/ml4w/hyprland-dotfiles"
readonly CACHE_FILE="$ML4W_CACHE/current_wallpaper"
readonly INTERVAL_FILE="$HOME/.config/ml4w/settings/wallpaper-automation.sh"
readonly WALLPAPER_DIR="$HOME/.config/ml4w/wallpapers"
readonly DEFAULT_WALLPAPER="$WALLPAPER_DIR/default.jpg"
readonly SET_WALLPAPER="$HOME/.config/hypr/scripts/wallpaper-set.sh"

export PATH="$PATH:$HOME/.local/bin"

# -----------------------------------------------------
# Single instance
# -----------------------------------------------------

# flock, not pgrep: the script path appears in the command line of whatever shell
# launched us, so a `pgrep -f wallpaper-boot.sh` match is as likely to be our own
# parent as a real second copy.

readonly LOCK_FILE="$ML4W_CACHE/wallpaper-boot.lock"
mkdir -p "$ML4W_CACHE"

# `exec 9>` would truncate the file on open, i.e. BEFORE flock decides whether we
# own it -- a losing second copy would blank the running copy's recorded pid and
# leave no way to stop it.  `<>` opens read-write without truncating; we truncate
# only once the lock is actually ours.
# Every child gets `9>&-`.  flock lives on the open file description, not the
# process, so an inherited fd 9 keeps the lock held for as long as that child
# lives -- and wallpaper.sh relaunches waybar and nwg-dock, which live for the
# whole session.  Without this, one rotation pass pins the lock until logout and
# no later copy can ever start.  (Observed: waybar holding fd 9w on this file.)
exec 9<>"$LOCK_FILE"
if ! flock -n 9; then
    echo ":: Another wallpaper-boot.sh already holds $LOCK_FILE (pid $(cat "$LOCK_FILE")) -- exiting"
    exit 0
fi
: >"$LOCK_FILE"
echo "$$" >&9

# -----------------------------------------------------
# Wait for swww-daemon to accept queries
# -----------------------------------------------------
# `swww query` is the only honest readiness probe: the daemon forks early but does
# not serve its socket until every output is bound.

if ! pgrep -x swww-daemon >/dev/null; then
    echo ":: Starting swww-daemon"
    setsid swww-daemon >/dev/null 2>&1 </dev/null 9>&- &
fi

for ((i = 0; i < DAEMON_TIMEOUT; i++)); do
    swww query >/dev/null 2>&1 && break
    sleep 1
done

if ! swww query >/dev/null 2>&1; then
    echo ":: swww-daemon did not become ready within ${DAEMON_TIMEOUT}s -- giving up"
    notify-send "Wallpaper" "swww-daemon failed to start; desktop background not set." 9>&-
    exit 1
fi
echo ":: swww-daemon ready after ${i}s"

# -----------------------------------------------------
# Restore the last wallpaper
# -----------------------------------------------------

wallpaper=""
if [ -f "$CACHE_FILE" ]; then
    sed -i "s|~|$HOME|g" "$CACHE_FILE"
    wallpaper=$(cat "$CACHE_FILE")
fi
[ -f "$wallpaper" ] || wallpaper="$DEFAULT_WALLPAPER"

echo ":: Restoring $wallpaper"
"$SET_WALLPAPER" "$wallpaper" 9>&-

# -----------------------------------------------------
# Rotate
# -----------------------------------------------------
# Interval comes from ML4W's settings file so the ML4W Settings app still governs
# it, and is re-read on every pass so a change takes effect at the next wake with
# no restart -- restarting would re-run the whole retheme just to pick up a number.
# An unreadable or non-numeric value means "stop rotating" rather than a busy loop:
# a full retheme fires on every change, so a bad interval is expensive.

read_interval() {
    local v
    v=$(cat "$INTERVAL_FILE" 2>/dev/null)
    [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge 10 ] || return 1
    echo "$v"
}

if ! interval=$(read_interval); then
    echo ":: No usable rotation interval in $INTERVAL_FILE -- rotation disabled"
    exit 0
fi

# Non-interactive bash does not act on a signal until the current foreground
# command finishes, so a plain `sleep "$interval"` makes the script ignore SIGTERM
# for up to a full interval -- at 4h that means `kill` appears to do nothing.
# Backgrounding the sleep and `wait`ing on it lets the trap run immediately.
sleep_pid=""
trap 'kill "$sleep_pid" 2>/dev/null; echo ":: Stopped"; exit 0' TERM INT

echo ":: Rotating every ${interval}s"
while true; do
    sleep "$interval" 9>&- &
    sleep_pid=$!
    wait "$sleep_pid"

    interval=$(read_interval) || {
        echo ":: Rotation interval in $INTERVAL_FILE is no longer usable -- stopping"
        exit 0
    }

    current=$(cat "$CACHE_FILE" 2>/dev/null)
    # default.jpg is the FALLBACK copy of a wallpaper that is also in the set under
    # its own name, so leaving it in the draw would show that image twice as often.
    next=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
                \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
                ! -name 'default.jpg' \
                ! -wholename "$current" | shuf -n 1)

    [ -n "$next" ] || continue
    "$SET_WALLPAPER" "$next" 9>&-
done
