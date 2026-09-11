-- Port of conf/custom.conf (hyprlang) — personal overrides.
-- Autostart entries live in lua/autostart.lua.

hl.config({
    input = {
        left_handed = true,
        kb_layout   = "lv",
        kb_variant  = "apostrophe",
    },
    general = {
        gaps_in  = 2,
        gaps_out = 2,
    },
})

hl.env("SDL_VIDEODRIVER", "wayland")

-- Take SUPER+S for the screenshot selection action (user-requested behaviour change).
--
-- ML4W binds `$mainMod, S` -> ~/.config/ml4w/scripts/sidepad.sh --init at
-- conf/keybindings/default.conf:77, reached via hyprland.conf:53 -> conf/keybinding.conf:1.
-- We deliberately take that key: unbind ML4W's binding, then bind SUPER+S to the same
-- command as SUPER+SHIFT+S, so both keys take a screenshot selection.
--
-- The key string must be UPPERCASE "SUPER + S" to match ML4W's own spelling. The hyprlang
-- source previously had `unbind = SUPER, s` (lowercase), which never matched and was a dead
-- no-op; it was corrected to `unbind = SUPER, S` in the hyprlang tree (commit 2f21733) and
-- verified live -- `hyprctl -j binds` now shows
--     modmask 64  key 'S'  -> exec '~/.local/bin/screenshot.sh selection'
-- where it previously showed sidepad.sh --init.
--
-- Ordering matters: the unbind must run after whatever registers ML4W's binding and before
-- the rebind below. Ordering relative to other modules is main.lua's responsibility.
-- Mirrors conf/custom.conf:44-46.
hl.unbind("SUPER + S")

hl.bind("SUPER + S",
        hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/screenshot.sh selection"),
        { description = "Screenshot selection" })

hl.bind("SUPER + SHIFT + S",
        hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/screenshot.sh selection"),
        { description = "Screenshot selection" })

hl.bind("SUPER + L",
        hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/power.sh lock"),
        { description = "Lock screen" })

-- Move the current workspace between monitors.
-- Argument shape verified against the Hyprland 0.55.4 binary: the hl.workspace.move
-- handler calls requireTableFieldMonitorSelector(.., "monitor", ..) (required) and
-- tableOptWorkspaceSelector(.., "workspace", ..) (optional). With "workspace" omitted it
-- resolves to the focused monitor's active workspace, i.e. movecurrentworkspacetomonitor.
-- The selector string is fed to CCompositor::getMonitorFromString, the same resolver the
-- hyprlang dispatcher uses, so "l"/"r"/"u"/"d" behave identically.
--
-- NOTE: CTRL+ALT+right is bound twice in the hyprlang source (to "r" and to "u").
-- Both entries are present in the live `hyprctl binds` list, so both are reproduced here in
-- source order. Behaviour preserved deliberately, defect NOT fixed —
-- see hypr-migration/conversion-report.md.
hl.bind("CTRL + ALT + left",  hl.dsp.workspace.move({ monitor = "l" }),
        { description = "Move workspace to monitor left" })
hl.bind("CTRL + ALT + right", hl.dsp.workspace.move({ monitor = "r" }),
        { description = "Move workspace to monitor right" })
hl.bind("CTRL + ALT + down",  hl.dsp.workspace.move({ monitor = "d" }),
        { description = "Move workspace to monitor below" })
hl.bind("CTRL + ALT + right", hl.dsp.workspace.move({ monitor = "u" }),
        { description = "Move workspace to monitor above (duplicate key, see conversion-report.md)" })
