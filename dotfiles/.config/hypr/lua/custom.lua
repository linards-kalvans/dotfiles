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

-- NOT PORTED, deliberately: conf/custom.conf:41 has `unbind = SUPER, s` (lowercase `s`).
-- It is a dead no-op in the live hyprlang config and is therefore reproduced as nothing.
--
-- Evidence: ML4W binds `$mainMod, S` -> ~/.config/ml4w/scripts/sidepad.sh --init at
-- conf/keybindings/default.conf:77, reached via hyprland.conf:53 -> conf/keybinding.conf:1.
-- custom.conf is sourced LAST (hyprland.conf:74), so its unbind runs after that bind --
-- yet `hyprctl -j binds` on the running config STILL lists:
--     modmask 64  key 'S'  -> exec '~/.config/ml4w/scripts/sidepad.sh --init'
-- So `unbind = SUPER, s` matches nothing today. The bind it was written for is the
-- commented-out custom.conf:42 (`# bind = SUPER, s, exec, ...screenshot.sh selection`),
-- superseded by the SUPER+SHIFT+S bind below.
--
-- Emitting any Lua form would risk making it live: `hl.unbind("SUPER + S")` matches ML4W's
-- own spelling exactly and would kill sidepad init; `hl.unbind("SUPER + s")` is only safe if
-- Lua bind matching is case-SENSITIVE, which the stub does not document and which cannot be
-- tested without a restart. Omitting it preserves today's behaviour under either rule.
--
-- Restoring an unbind of Super+S is a deliberate user decision, not a migration step.
-- (For the record, ML4W's screenshot bind is `$mainMod ALT, S` -> screenshot.sh
-- --instant-area at default.conf:55, live as modmask 72 -- NOT Super+S.)

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
