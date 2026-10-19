--    __  _____  _____      __  _____          ___
--   /  |/  / / / / / | /| / / / ___/__  ___  / _/
--  / /|_/ / /_/_  _/ |/ |/ / / /__/ _ \/ _ \/ _/
-- /_/  /_/____//_/ |__/|__/  \___/\___/_//_/_/
--
-- Port of conf/ml4w.conf (sourced at hyprland.conf:69).
--
-- Produced with `hyprlang2lua -r -c` (0.7.1-1), then hand-corrected. The converter
-- reported `translated=35 passthrough=35 flagged=6 coverage=85.4%` and exited 3; all
-- six flags were the `layerrule2` lines, hand-written below. Everything else is the
-- converter's output verbatim, reviewed line by line against
-- /usr/share/hypr/stubs/hl.meta.lua and /usr/share/hypr/hyprland.lua.
--
-- Directive counts asserted against the source (conf/ml4w.conf):
--     6 layerrule2      ->   6 hl.layer_rule calls
--    17 windowrule { }  ->  17 hl.window_rule calls
--    17 env             ->  17 hl.env calls
--     1 xwayland block  ->   1 hl.config call
-- `grep -cE '^\s*envd\s*=' conf/ml4w.conf` is 0, so no call takes hl.env's third
-- (dbus) argument.
--
-- QT_QPA_PLATFORMTHEME is set TWICE on purpose -- qt6ct then qt5ct, exactly as
-- ml4w.conf:189-190 does. The later call wins; collapsing them changes Qt theming.
-- Source order is preserved throughout, including the xwayland block sitting between
-- the Ozone envs and SDL_VIDEODRIVER (the converter's hl.config merging had hoisted
-- it past the SDL line; moved back by hand for auditability -- config keys and env
-- are order-independent relative to each other, so this is cosmetic).
--
-- The two commented-out `windowrule =` lines for xdg-desktop-portal-gtk are carried
-- over as comments, as in the source. They were already inactive.

-- SwayNC layer rules (ml4w.conf:8-13) -- HAND-WRITTEN, the converter flagged all six.
--
-- hyprlang2lua knows `layerrule`, not `layerrule2`, so each of the six came back as
--     -- TODO: manual review - top-level key 'layerrule2 = ...' has no enclosing section
-- Re-running the converter on the equivalent `layerrule =` spelling produced the
-- `match = { namespace = ... }` + effect-field shape used below, which also matches the
-- commented layer-rule example at /usr/share/hypr/hyprland.lua:342-347 and
-- HL.LayerRuleSpec in the stub (fields: blur, ignore_alpha, match, name, ...).
--
-- One hl.layer_rule call per source directive, in source order, rather than three
-- merged calls per namespace: it keeps the mapping 1:1 for tools/hypr-config-audit, and
-- layer rules accumulate in application order exactly as they do in hyprlang.
--
-- `ignorezero` (ml4w.conf:10-11) has no equivalent on Hyprland 0.55.4. HL.LayerRuleSpec
-- offers only `ignore_alpha`, and the literal "ignorezero" appears nowhere in
-- /usr/bin/Hyprland -- its layer-rule effect table spells everything with underscores
-- (blur_popups, ignore_alpha, above_lock, no_anim, no_screen_share). The converter
-- flags it too ("unmapped layer rule: ignorezero"). Ported as `ignore_alpha = 0`, the
-- numeric threshold that reproduces "ignore fully transparent pixels".
-- Deliberately NOT `ignore_alpha = true`: the `number|boolean` union in the stub is a
-- stub-generator artefact carried by every numeric field (`sensitivity? number|boolean`
-- is the same shape, and a boolean sensitivity is meaningless), and a coercion to 1.0
-- would read as "ignore every pixel below full opacity" -- no blur at all. In any case
-- both namespaces are re-ruled two directives later with `ignore_alpha = 0.5`, which
-- supersedes this, so the residual risk is nil.
--
-- DELIBERATE FIX, not an open risk: `layerrule2` is NOT a keyword on Hyprland 0.55.4,
-- and these six ML4W rules have been SILENT NO-OPS in the hyprlang tree. Proven, not
-- inferred:
--
--   * Config::Legacy::CConfigManager's constructor registers the `layerrule` handler at
--     0x4234a1 with allowFlags = 0:
--         lea    0x7971aa(%rip),%rdx   # bba652 -> "layerrule"
--         lea    -0x346f(%rip),%rsi    # 420040 -> handleLayerrule
--         movabs $0x1337beef00000000,%rcx      <- SHandlerOptions, allowFlags = 0
--         call   *...                          # Hyprlang::CConfig::registerHandler
--     `bind` (0x4233f5) and `env` pass $0x1337beef00000001 instead. That flag is the
--     mechanism behind bind -> binde/bindl and env -> envd prefix matching. With
--     allowFlags = 0, the string "layerrule2" cannot reach the `layerrule` handler.
--     (A plain `strings` check cannot see this, which is what misled the first pass.)
--   * Tested directly against the real libhyprlang.so.0.6.8 with the `layerrule` handler
--     and special category registered exactly as Hyprland does: `layerrule2 = blur, ...`
--     calls no handler and raises no error, while `bindd` does reach the `bind` handler.
--     hyprlang silently DISCARDS unknown TOP-LEVEL keys; only an unknown key on a known
--     route (e.g. input:kb_lyout) is an error.
--   * Live evidence agrees: `hyprctl configerrors` returns an empty list and exits 0
--     (it IS implemented on this build -- the "unknown request" seen in the first pass
--     came from `hyprctl layerrules`, a different command that does not exist), and the
--     34 MB session log contains zero `ERR ]` lines.
--
-- Porting them anyway is the adjudicated choice: the intent is unambiguous, the blast
-- radius is one cosmetic effect, and reproducing an upstream typo would mean writing six
-- rules whose only purpose is to not work.
--
-- EXPECTED DIFFERENCE AT FIRST LUA RESTART: swaync control-centre and notification-window
-- blur switches ON. That is a behaviour gain from fixing a dead directive, not a
-- migration error -- Task 11 should record it as expected rather than investigate it.

hl.layer_rule({
    match = { namespace = "swaync-control-center" },
    blur = true,
})

hl.layer_rule({
    match = { namespace = "swaync-notification-window" },
    blur = true,
})

hl.layer_rule({
    match = { namespace = "swaync-control-center" },
    ignore_alpha = 0, -- source: `ignorezero`; see the note above
})

hl.layer_rule({
    match = { namespace = "swaync-notification-window" },
    ignore_alpha = 0, -- source: `ignorezero`; see the note above
})

hl.layer_rule({
    match = { namespace = "swaync-control-center" },
    ignore_alpha = 0.5,
})

hl.layer_rule({
    match = { namespace = "swaync-notification-window" },
    ignore_alpha = 0.5,
})

-- Pavucontrol
hl.window_rule({
    name = "pavucontrol",
    match = {
        class = "(.*org.pulseaudio.pavucontrol.*)",
    },
    float = true,
    center = true,
    pin = true,
    size = "700 600",
})

-- Waypaper
hl.window_rule({
    name = "waypaper",
    match = {
        class = "(.*waypaper.*)",
    },
    float = true,
    center = true,
    pin = true,
    size = "900 700",
})

-- Newelle
hl.window_rule({
    name = "newelle",
    match = {
        class = "(io.github.qwersyk.Newelle)",
    },
    float = true,
    center = true,
    pin = true,
    size = "1000 700",
})

-- ML4W Calendar
hl.window_rule({
    name = "ml4w-calendar",
    match = {
        class = "(com.ml4w.calendar)",
    },
    float = true,
    move = "monitor_w-window_w-18 85",
    pin = true,
    size = "400 400",
})

-- ML4W Sidebar
hl.window_rule({
    name = "ml4w-sidebar",
    match = {
        class = "(com.ml4w.sidebar)",
    },
    float = true,
    move = "monitor_w-window_w-18 91",
    pin = true,
    size = "400 660",
})

-- ML4W Welcome
hl.window_rule({
    name = "ml4w-welcome",
    match = {
        class = "(com.ml4w.welcome)",
    },
    float = true,
    center = true,
    pin = true,
    size = "700 600",
})

-- ML4W Settings
hl.window_rule({
    name = "ml4w-settings",
    match = {
        class = "(com.ml4w.settings)",
    },
    float = true,
    center = true,
    pin = true,
    size = "800 600",
})

-- Blueman Manager
hl.window_rule({
    name = "blueman-manager",
    match = {
        class = "(blueman-manager)",
    },
    float = true,
    center = true,
    size = "800 600",
})

-- nwg-look
hl.window_rule({
    name = "nwg-look",
    match = {
        class = "(nwg-look)",
    },
    float = true,
    center = true,
    size = "700 600",
})

-- nwg-displays
hl.window_rule({
    name = "nwg-displays",
    match = {
        class = "(nwg-displays)",
    },
    float = true,
    center = true,
    size = "900 600",
})

-- System Mission Center
hl.window_rule({
    name = "missioncenter",
    match = {
        class = "(io.missioncenter.MissionCenter)",
    },
    float = true,
    center = true,
    pin = true,
    size = "900 600",
})

-- Gnome Calculator
hl.window_rule({
    name = "gnome-calculator",
    match = {
        class = "(org.gnome.Calculator)",
    },
    float = true,
    center = true,
    size = "700 600",
})

-- Hyprland Share Picker
hl.window_rule({
    name = "hyprland-share-picker",
    match = {
        class = "(hyprland-share-picker)",
    },
    float = true,
    pin = true,
    center = true,
    size = "600 400",
})

-- nm-connection-editor
hl.window_rule({
    name = "nm-connection-editor",
    match = {
        class = "(nm-connection-editor)",
    },
    float = true,
    center = true,
    size = "800 700",
})

-- Picture-in-Picture
hl.window_rule({
    name = "Picture-in-Picture",
    match = {
        title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$",
    },
    float = true,
    pin = true,
    center = true,
})

-- General floating
hl.window_rule({
    name = "dotfiles-floating",
    match = {
        class = "(dotfiles-floating)",
    },
    float = true,
    center = true,
    size = "1000 700",
})

-- Dotfiles Sidepad
hl.window_rule({
    name = "dotfiles-sidepad",
    match = {
        class = "(dotfiles-sidepad)",
    },
    float = true,
    pin = true,
    center = true,
    size = "1000 700",
})

-- Float and center file pickers
-- windowrule = float, class:xdg-desktop-portal-gtk, title:^(Open.*Files?|Save.*Files?|All Files|Save)
-- windowrule = center, class:xdg-desktop-portal-gtk, title:^(Open.*Files?|Save.*Files?|All Files|Save)

-- XDG Desktop Portal
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- QT
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")

-- GDK
hl.env("GDK_SCALE", "1")

-- Toolkit Backend
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("CLUTTER_BACKEND", "wayland")

-- Mozilla
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Set the cursor size for xcursor
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Ozone
hl.env("OZONE_PLATFORM", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")

-- XWayland
hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})

-- SDL version
hl.env("SDL_VIDEODRIVER", "wayland")
