-- Monitor layout pinned by DESCRIPTION, not by connector name.
--
-- Required from main.lua in place of `require("monitors")`; it loads that module
-- itself, below, and then overrides it.
--
-- Why: DP-MST connector names are not stable. The dock's two Dells enumerate as
-- DP-5/DP-6 on one plug and DP-7/DP-8 on the next, because MST destroys and
-- recreates its connectors on every topology change. A layout pinned to DP-N
-- silently stops applying the moment the names shift, and the catch-all
-- `monitor=,preferred,auto,1` from lua/monitors/default.lua then places both
-- externals to the RIGHT of eDP-1 instead of the left. Observed 2026-09-17:
-- monitors.lua still pinned DP-7/DP-8 after a reboot had renamed them back to
-- DP-5/DP-6, so the layout came up as eDP-1@3840, DP-5@5760, DP-6@7680.
--
-- Descriptions are stable across re-enumeration, so they are the correct key.
-- `desc:` is a prefix on the `output` field, not a separate MonitorSpec field.
--
-- Related: linux-debug/dock-mst-modeset-einval-2026-09-17.md
--
-- nwg-displays' own name-based output is loaded FIRST, below, and kept as a
-- fallback so arranging displays in that GUI still takes effect for whatever the
-- connectors happen to be called right now. The desc: rules that follow are
-- applied after it and therefore win. Revert to name-based pinning by pointing
-- main.lua back at `require("monitors")`.
--
-- hyprlang mirror: conf/monitors/desc-pinned.conf, sourced from custom.conf
-- immediately after conf/monitors/nwg-displays.conf. Keep the two in sync.

-- nwg-displays, name-based (monitors.lua). Overridden by the desc: rules below.
require("monitors")

-- Internal panel. eDP-1 is a fixed connector, so the name is stable here.
hl.monitor({
    output = "eDP-1",
    mode = "1920x1200@60.0",
    position = "3840x0",
    scale = 1.0,
    vrr = 0,
})

-- Left external: Dell P2314H on the UGREEN dock (DP alt mode + MST).
hl.monitor({
    output = "desc:Dell Inc. DELL P2314H J8J314CFB2YS",
    mode = "1920x1080@60.0",
    position = "0x0",
    scale = 1,
    vrr = 0,
})

-- Centre external: Dell E2420HS on the same dock.
hl.monitor({
    output = "desc:Dell Inc. DELL E2420HS DXG3X03",
    mode = "1920x1080@60.0",
    position = "1920x0",
    scale = 1,
    vrr = 0,
})
