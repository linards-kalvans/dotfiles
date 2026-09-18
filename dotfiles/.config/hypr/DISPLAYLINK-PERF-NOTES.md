# DisplayLink Performance Issues & Fixes

## Problem
Hyprland animations become slow when USB/DisplayLink docking station is connected or disconnected.

## Root Causes

### 1. EVDI framebuffer copy is CPU-bound (highest impact)
The EVDI driver copies every rendered frame from GPU to a software buffer via CPU, then sends over USB. Every animation frame on DisplayLink monitors (DP-7/DP-8) goes through this path, which can drag down smoothness on ALL monitors including eDP-1.

### 2. Phantom monitors on disconnect
When the dock is unplugged, Hyprland may keep rendering to the now-gone monitors, wasting resources and causing lag on eDP-1.
- Known issue: https://github.com/hyprwm/Hyprland/discussions/10152

### 3. Heavy effects multiplied across 3 monitors
- Blur: 4 passes at size 4 — multiplied across 3 monitors, then CPU-copied via EVDI
- Shadows: range 32 — adds per-frame cost
- Inactive opacity: 0.9 — forces alpha compositing on every inactive window
- Complex animations (End-4 beziers, popin/slide) — many intermediate frames

### 4. Workspace/monitor name mismatch
workspaces.conf references DP-5/DP-6, but monitors.conf defines DP-7/DP-8. DisplayLink monitors get different DP-N names on each connect.

---

## Fixes

### Quick config changes
1. Reduce blur passes from 4 to 2 in decoration config
2. Add `vfr = true` to misc section (reduces frames when nothing changes)
3. Set `inactive_opacity = 1.0` when docked

### Fix phantom monitors on disconnect
Run on disconnect:
```bash
hyprctl keyword monitor DP-7,disable
hyprctl keyword monitor DP-8,disable
```
Or automate with udev rule / https://github.com/prabhanshu11/hyprland-monitor-fix

### Automated docked/undocked profile script
```bash
#!/bin/bash
MONITORS=$(hyprctl monitors -j | jq length)
if [ "$MONITORS" -gt 1 ]; then
    # Docked - reduce effects
    hyprctl keyword decoration:blur:passes 2
    hyprctl keyword decoration:shadow:enabled false
    hyprctl keyword decoration:inactive_opacity 1.0
else
    # Undocked - full effects
    hyprctl keyword decoration:blur:passes 4
    hyprctl keyword decoration:shadow:enabled true
    hyprctl keyword decoration:inactive_opacity 0.9
fi
```

### Long term
If the laptop has Thunderbolt/USB4, a dock with native DisplayPort passthrough would bypass EVDI entirely and eliminate the CPU copy bottleneck. DisplayLink should be considered a last resort on Linux/Wayland.

### Keep packages updated
- Current: evdi-dkms 1.14.14, displaylink 6.2
- Check for newer versions at https://github.com/DisplayLink/evdi

### Regenerate workspace config
Run nwg-displays when docked to ensure workspace assignments reference the correct DP-N identifiers.
