-- Port of conf/autostart.conf, the exec-once lines from conf/custom.conf, and conf/cursor.conf.
-- hyprlang's `exec-once = [workspace N silent] cmd` becomes a call with a rules table:
-- cmd, then { workspace = N, silent = true } as the second argument.
--
-- exec_cmd rules shape: `silent` is its own boolean key, NOT folded into the workspace
-- value as a compound string ("3 silent"). Evidence:
--   - hl.meta.lua declares `rules?: table<string, string|number|boolean>` — the boolean
--     variant only makes sense for bare-keyword rules (silent, float, pin, ...), which is
--     exactly how hyprlang's own bracket syntax works (`[workspace 3 silent]` is two rule
--     tokens, "workspace 3" and "silent", not one).
--   - `strings /usr/bin/Hyprland` contains a literal "workspace {} silent" format template,
--     sitting alongside CWindowRule::buildFromExecString and
--     Config::Supplementary::CExecutor::spawnWithRules — consistent with the rules table
--     being reassembled into that exact phrase from separate `workspace` and `silent` entries.
-- This is inference from strings, not a decompiled read of the Lua binding itself.
-- UNVERIFIED until hyprland.lua is symlinked in and Hyprland restarts onto the Lua config
-- (Task 11's manual checklist must confirm Brave/Zen land on workspaces 2/3/9 as silent).

hl.on("hyprland.start", function()
    -- Cursor theme (from conf/cursor.conf)
    hl.exec_cmd("hyprctl setcursor ArcStarry-cursors 24")

    -- Brave progressive web apps, workspace 3 (from conf/custom.conf)
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

    -- ML4W stock autostart (from conf/autostart.conf)
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
end)
