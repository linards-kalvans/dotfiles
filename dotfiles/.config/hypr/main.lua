-- Hyprland Lua configuration.
--
-- Load order mirrors hyprland.conf's own `source =` sequence, verified line by
-- line. The hyprlang line number is given for each entry so the two trees can be
-- checked against each other.
--
-- See docs/superpowers/specs/2026-09-11-hyprland-lua-migration-design.md
-- Switch back to hyprlang with: hypr-config-mode conf && restart Hyprland

-- The 9 ML4W variation modules, selected by the .conf pointer files:
--   monitor.conf      :16    window.conf     :48    keybinding.conf :53
--   environment.conf  :26    decoration.conf :49    windowrule.conf :54
--   workspace.conf    :51    layout.conf     :50    animation.conf  :59
-- Regenerate after changing a variation in the ML4W Settings app:
--   ml4w-variations-sync
require("lua.variations")

-- conf/keyboard.conf :31 — base input block. Must precede lua.custom, which
-- overrides kb_layout/kb_variant, exactly as the hyprlang tree does.
require("lua.keyboard")

-- colors.conf :36 — matugen output, regenerated on every wallpaper change.
local colors = require("lua.colors")

-- hyprland.conf's own directives :37, :38, :64 — the $color8/$color11 aliases
-- and the dbus-update-activation-environment exec-once that
-- xdg-desktop-portal-hyprland needs for screensharing.
require("lua.toplevel")

-- conf/misc.conf :52 — misc and debug blocks.
require("lua.misc")

-- conf/ml4w.conf :69 — swaync layer rules and ML4W's window rules.
require("lua.ml4w")

-- conf/custom.conf :74 — personal overrides: input, gaps, env, custom binds.
require("lua.custom")

-- Monitor layout. In the hyprlang tree this arrives via custom.conf :58 sourcing
-- conf/monitors/nwg-displays.conf, so it must come after the monitor variation
-- in order to win. Workspace pinning is deliberately absent -- dropped at the
-- user's request; see the spec.
--
-- Pinned by DESCRIPTION, not by connector name: DP-MST recreates its connectors
-- on every topology change, so DP-5/DP-6 become DP-7/DP-8 and a name-based
-- layout silently stops applying. nwg-displays still regenerates monitors.lua
-- (name-based); it is no longer loaded. Revert with: require("monitors").
require("lua.monitors_pin")

-- conf/cursor.conf :21 and conf/autostart.conf :43. Registered last because
-- hl.on("hyprland.start", ...) is a callback -- where it is registered does not
-- affect when it fires -- and keeping every spawn in one module is clearer than
-- splitting it to match source position.
require("lua.autostart")
