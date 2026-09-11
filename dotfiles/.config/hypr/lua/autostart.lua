-- Port of conf/cursor.conf, conf/autostart.conf, and the exec-once lines from conf/custom.conf.
-- Order matches hyprland.conf's own `source =` sequence: cursor.conf (line 21), then
-- autostart.conf (line 43), then custom.conf (line 74) — verified against the live file.
--
-- hyprlang's `exec-once = [workspace N silent] cmd` becomes a call with a rules table:
-- cmd, then { workspace = N, silent = true } as the second argument.
--
-- exec_cmd rules shape: `silent` is its own boolean key, NOT folded into the workspace
-- value as a compound string ("3 silent"). Evidence:
--   - hl.meta.lua declares `rules?: table<string, string|number|boolean>` — the boolean
--     variant only makes sense for bare-keyword rules (silent, float, pin, ...), which is
--     exactly how hyprlang's own bracket syntax works (`[workspace 3 silent]` is two rule
--     tokens, "workspace 3" and "silent", not one).
--   - On-disk convention is one-field-per-concept, never a compound string, everywhere this
--     API is used for real: /usr/share/hypr/hyprland.lua:275-278 calls
--     hl.dsp.focus({ workspace = i }) / hl.dsp.window.move({ workspace = i }) inside a
--     `for i = 1, 10` loop with `workspace` as a bare Lua number, never combined with another
--     rule word; the same file's hl.bind(..., { locked = true, repeating = true }) idiom uses
--     one independent boolean key per flag. hl.meta.lua's HL.BindOptions and
--     HL.WorkspaceRuleSpec are likewise one-field-per-concept. Nothing on disk combines two
--     rule concepts into one string value.
--   - `strings /usr/bin/Hyprland` contains a literal "workspace {} silent" format template,
--     whose near neighbours (~40 bytes away) are `HL_EXEC_RULE_TOKEN` and
--     "Failed to parse exec rule: {}" — genuine exec-rule-parsing context, consistent with the
--     rules table being reassembled into that phrase from separate `workspace` and `silent`
--     entries. (CWindowRule::buildFromExecString and CExecutor::spawnWithRules are real symbols
--     in the same binary but ~100KB/~1MB away from this string — not actually nearby; not cited
--     as proximity evidence.)
-- No literal exec_cmd(cmd, {rules}) example exists on disk, so this remains inference,
-- confirmed by the on-disk conventions above rather than a decompiled read of the Lua binding
-- itself. UNVERIFIED until hyprland.lua is symlinked in and Hyprland restarts onto the Lua
-- config (Task 11's manual checklist must confirm Brave/Zen land on workspaces 2/3/9 as silent).

hl.on("hyprland.start", function()
    -- Cursor theme (from conf/cursor.conf, sourced at hyprland.conf:21)
    hl.exec_cmd("hyprctl setcursor ArcStarry-cursors 24")

    -- ML4W stock autostart (from conf/autostart.conf, sourced at hyprland.conf:43)
    hl.exec_cmd("~/.config/ml4w/listeners.sh --startall")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("swww-daemon")
    hl.exec_cmd("~/.config/hypr/scripts/wallpaper-restore.sh")
    hl.exec_cmd("swaync")
    hl.exec_cmd("~/.config/hypr/scripts/gtk.sh")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("~/.config/ml4w/scripts/ml4w-autostart.sh")
    hl.exec_cmd("~/.config/waybar/launch.sh")
    hl.exec_cmd("~/.config/hypr/scripts/cleanup.sh")
    hl.exec_cmd("wl-clip-persist --clipboard regular")

    -- Brave progressive web apps, workspace 3 (from conf/custom.conf, sourced at hyprland.conf:74)
    hl.exec_cmd(
        "/opt/brave-bin/brave --profile-directory=Default " ..
        "--app-id=cifhbcnohmdccbgoicgdjpfamggdegmo --app-run-on-os-login-mode=windowed",
        { workspace = 3, silent = true })
    hl.exec_cmd(
        "/opt/brave-bin/brave --profile-directory=Default " ..
        "--app-id=pkooggnaalmfkidjmlhoelhdllpphaga --app-run-on-os-login-mode=windowed",
        { workspace = 3, silent = true })

    -- Main browser, workspace 2 (from conf/custom.conf)
    hl.exec_cmd("brave %U", { workspace = 2, silent = true })

    -- Zen Browser, workspace 9 (from conf/custom.conf)
    hl.exec_cmd(
        "zen-browser --class=zenbrowserlinards " ..
        "--profile /home/linards/.config/zen-linards",
        { workspace = 9, silent = true })

    -- Background services, no workspace placement (from conf/custom.conf)
    hl.exec_cmd("/opt/pcloud/pcloud-drive.AppImage")
    hl.exec_cmd("solaar -w hide")
end)
