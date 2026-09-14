-- PROBE BUILD — replaced in Task 11.
-- Variant A: dotted module path.
local ok, err = pcall(require, "lua.probe")

hl.on("hyprland.start", function()
    -- Self-report: the probe session has no keybindings, so it cannot be
    -- inspected interactively. Write the verdict to a file instead.
    hl.exec_cmd("sh -c '"
        .. "{ echo \"require_ok=" .. tostring(ok) .. "\";"
        .. "  echo \"require_err=" .. tostring(err):gsub("'", "") .. "\";"
        .. "  echo -n \"gaps_out=\"; hyprctl getoption general:gaps_out | tr \"\\n\" \" \";"
        .. "  echo; echo -n \"config_file=\";"
        .. "  grep -a \"Using config:\" \"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log\" | tail -1;"
        .. "} > $HOME/probe-result.txt 2>&1'")

    -- An escape hatch, so the probe session is usable rather than stranded.
    hl.exec_cmd("kitty")
end)

-- SUPER+Return opens a terminal; SUPER+Q closes a window; SUPER+M exits Hyprland.
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"), { description = "Terminal" })
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Close window" })
hl.bind("SUPER + M", hl.dsp.exit(), { description = "Exit Hyprland" })
