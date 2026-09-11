-- Port of conf/keyboard.conf (sourced at hyprland.conf:31).
--
-- Produced by `hyprlang2lua -r -c` (0.7.1-1), which reported
-- `translated=11 passthrough=4 flagged=0 coverage=100.0%` and exited 0 -- nothing
-- needed manual review. Only this provenance header was added by hand.
--
-- Directive count asserted against the source: 11 settings in the `input` block
-- (15 non-comment, non-blank lines minus the 4 brace lines) -> 11 keys below.
-- Every key checked against the HL.ConfigKey enum in
-- /usr/share/hypr/stubs/hl.meta.lua: input.kb_layout, input.kb_variant,
-- input.kb_model, input.kb_options, input.numlock_by_default, input.follow_mouse,
-- input.mouse_refocus, input.touchpad.natural_scroll, input.touchpad.scroll_factor,
-- input.touchpad.disable_while_typing, input.sensitivity.
--
-- kb_layout stays "us" ON PURPOSE. lua/custom.lua (port of conf/custom.conf, the
-- last file hyprland.conf sources, at :74) overrides it to "lv"/"apostrophe" later
-- in the load order, exactly as the hyprlang tree does. Preserving that override
-- chain is the point -- do not "fix" this to lv. For the same reason the three
-- empty values (kb_variant/kb_model/kb_options) are kept as explicit empty strings
-- rather than dropped: hyprlang assigns them the empty string here, and dropping
-- them would leave whatever Hyprland's defaults are.

hl.config({
    input = {
        kb_layout = "us",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        numlock_by_default = true,
        follow_mouse = 1,
        mouse_refocus = false,
        touchpad = {
            natural_scroll = false,
            scroll_factor = 1.0, -- Touchpad scroll factor
            disable_while_typing = false,
        },
        sensitivity = 0, -- Pointer speed: -1.0 - 1.0, 0 means no modification.
    },
})
