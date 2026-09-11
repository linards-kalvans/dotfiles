-- Port of conf/misc.conf (sourced at hyprland.conf:52).
-- Note: vfr moved from misc to debug in Hyprland 0.55; the hyprlang source
-- already reflects that.
--
-- Directive count asserted against the source: 4 non-comment settings in
-- conf/misc.conf -> 4 keys below. Every key checked against the HL.ConfigKey
-- enum in /usr/share/hypr/stubs/hl.meta.lua (misc.disable_hyprland_logo,
-- misc.disable_splash_rendering, misc.initial_workspace_tracking, debug.vfr).

hl.config({
    misc = {
        disable_hyprland_logo      = true,
        disable_splash_rendering   = true,
        initial_workspace_tracking = 1,
    },
    debug = {
        vfr = true,
    },
})
