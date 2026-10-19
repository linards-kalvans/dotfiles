#!/bin/bash
# Watch logind's PrepareForSleep signal and re-enable DPMS on resume.
#
# Why a D-Bus watcher and not `WantedBy=sleep.target`: sleep.target is a *system* unit.
# The systemd --user manager has no sleep.target (checked on systemd 261, this host), so a
# user unit ordered against it is silently never started -- `systemctl --user enable` even
# says so: "added as a dependency to a non-existent unit sleep.target".
#
# Purpose: after a suspend that hypridle requested itself (`systemctl suspend` from its
# 7200s listener) hypridle's before_sleep_cmd/after_sleep_cmd do not run, so nothing turns
# the outputs back on and the machine resumes with every panel dark.
# See linux-debug/suspend-blank-screen-after-auto-suspend-2026-09-18.md.
#
# This path does not depend on hypridle running, firing, or seeing input activity.
# Turning DPMS on when it is already on is a no-op, so a redundant call is harmless.

set -uo pipefail

self_dir=$(dirname "$(readlink -f "$0")")

# PrepareForSleep(true) is emitted before suspend, PrepareForSleep(false) after resume.
gdbus monitor --system \
      --dest org.freedesktop.login1 \
      --object-path /org/freedesktop/login1 2>/dev/null |
while read -r line; do
    case "$line" in
        *PrepareForSleep*false*)
            "$self_dir/dpms-on.sh" || true
            ;;
    esac
done
