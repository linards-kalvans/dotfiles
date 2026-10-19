-- Port of conf/cursor.conf, conf/autostart.conf, and the exec-once/exec lines from
-- conf/custom.conf. Order matches hyprland.conf's own `source =` sequence: cursor.conf
-- (line 21), then autostart.conf (line 43), then custom.conf (line 74) — verified against
-- the live file. (hyprland.conf:64's separate dbus `exec-once` belongs to Task 9, not here.)
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
--
-- conf/autostart.conf:41 uses `exec` (not `exec-once`): `~/.config/com.ml4w.hyprlandsettings/
-- hyprctl.sh`, the ML4W Hyprland Settings app's apply-on-reload hook. hyprlang's `exec` runs at
-- startup AND on every subsequent config reload, unlike `exec-once`. The exec_cmd call itself
-- has no "repeat on reload" option (checked: only `exec_cmd(cmd, rules?)`, no such flag exists).
-- The Lua API's `hyprland.start` event only covers the startup half. But HL.EventName includes a
-- distinct "config.reloaded" event (confirmed in both hl.meta.lua and the compiled binary's
-- event-name table, listed as a sibling of "hyprland.start"), so the hyprctl.sh call below is
-- run from BOTH hl.on("hyprland.start", ...) and a second hl.on("config.reloaded", ...)
-- subscription to reproduce "runs at startup and on every reload". UNVERIFIED: whether
-- "config.reloaded" ALSO fires during the very first config parse at startup (which would mean
-- hyprctl.sh runs twice at boot instead of once) or only on true `hyprctl reload`s (which would
-- make this an exact match for `exec`). No on-disk source settles this either way; confirm at
-- Task 11's manual restart and at the first reload after it. A duplicate run at boot of this
-- particular idempotent settings-apply script is a low-severity risk either way.

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

    -- ML4W Hyprland Settings app hook (from conf/autostart.conf:41, `exec` not `exec-once`).
    -- Startup half of the reload-repeating behaviour; see the config.reloaded subscription
    -- below for the reload half, and the header comment for the full caveat.
    hl.exec_cmd("~/.config/com.ml4w.hyprlandsettings/hyprctl.sh")

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

    -- Wallpaper bring-up + rotation (interval from ml4w/settings/wallpaper-automation.sh).
    -- Supersedes the `swww-daemon` and `wallpaper-restore.sh` spawns above, which
    -- race: swww-daemon exits if it cannot
    -- bind the outputs this early, and wallpaper-restore.sh then calls waypaper against
    -- a dead socket and fails silently. Those two are left in place (they are a 1:1 port
    -- of ML4W's conf/autostart.conf); this script is idempotent and repairs whatever
    -- they left behind. Mirror of conf/custom.conf; keep the two in sync.
    -- Revert by deleting this call.
    hl.exec_cmd("~/.config/hypr/scripts/wallpaper-boot.sh")

    -- Per-dock monitor layout memory. Restores the layout last used with the current
    -- set of monitors (keyed by their descriptions) at startup and on every
    -- monitoradded/monitorremoved -- i.e. dock connect and disconnect -- and learns
    -- the layout back once it has held still for 20s, so an nwg-displays change is
    -- remembered rather than clobbered. A monitor set it has never seen falls back to
    -- ~/.config/hypr/monitor-pins.conf.
    -- This lives outside the sourced config on purpose: nwg-displays applies by
    -- writing the generated monitors file and Hyprland auto-reloads on that write, so
    -- anything sourced afterwards is re-applied by that reload and clobbers the change.
    -- Store: ~/.local/state/hypr/monitor-profiles.json
    -- Mirror of conf/custom.conf; keep the two in sync. Revert by deleting this call.
    hl.exec_cmd("~/.config/hypr/scripts/monitor-pin.py watch")
end)

-- Reload half of conf/autostart.conf:41's `exec` directive (see header comment for full
-- rationale and the unverified double-fire-at-boot caveat).
hl.on("config.reloaded", function()
    hl.exec_cmd("~/.config/com.ml4w.hyprlandsettings/hyprctl.sh")
end)
