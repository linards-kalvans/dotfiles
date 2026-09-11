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

-- ML4W binds SUPER+S to its own screenshot action; replace it with SUPER+SHIFT+S.
hl.unbind("SUPER + S")

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
