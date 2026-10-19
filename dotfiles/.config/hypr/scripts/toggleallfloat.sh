#!/usr/bin/env bash
#     _    _ _  __ _             _
#    / \  | | |/ _| | ___   __ _| |_
#   / _ \ | | | |_| |/ _ \ / _` | __|
#  / ___ \| | |  _| | (_) | (_| | |_
# /_/   \_\_|_|_| |_|\___/ \__,_|\__|
#

# Was: hyprctl dispatch workspaceopt allfloat
#
# `workspaceopt` HAS NO LUA BINDING on Hyprland 0.55.4 and is therefore
# unreachable from a Lua config. Established 2026-09-15 by full enumeration of the
# live API (not from docs):
#   pairs(hl.dsp)           -> cursor, dpms, event, exec_cmd, exec_raw, exit, focus,
#                              force_idle, force_renderer_reload, global, group,
#                              layout, no_op, pass, send_key_state, send_shortcut,
#                              submap, window, workspace
#   pairs(hl.dsp.workspace) -> move, rename, swap_monitors, toggle_special
#   hl.dsp.workspaceopt / workspace_opt / workspace.opt / workspace.option -> all nil
# The dispatcher still exists inside the compositor (it is in Hyprland's dispatcher
# name table) but is marked deprecated there, and only the hyprlang text parser can
# reach it -- under Lua, `hyprctl dispatch workspaceopt allfloat` is a syntax error.
#
# EMULATION (below) -- close, but NOT identical:
#   - Same: toggles every window on the active workspace between tiled and floating.
#   - Different: workspaceopt set a WORKSPACE-LEVEL flag, so windows opened later
#     also floated. This sets each window individually, so NEW windows still tile.
# It uses hl.dispatch(function() ... end), which executes arbitrary Lua (verified),
# with hl.dsp.window.float({ window = <w>, action = "set"|"unset" }) per window --
# an explicit set/unset, not a per-window toggle, so a workspace with a mix of
# floating and tiled windows converges to all-floating rather than inverting.

# The active workspace MUST be resolved here, not in Lua: hl.get_active_workspace()
# called over IPC returns the first monitor's workspace, not the focused one
# (verified: reported HL.Workspace(1:1) while the focus was on workspace 7).
ws=$(hyprctl activeworkspace -j | jq -r '.id')

hyprctl dispatch "$(cat <<EOF
function()
  local wins = hl.get_workspace_windows($ws)
  local target = false
  for _, w in ipairs(wins) do if not w.floating then target = true break end end
  for _, w in ipairs(wins) do
    if w.floating ~= target then
      hl.dispatch(hl.dsp.window.float({ window = w, action = target and "set" or "unset" }))
    end
  end
end
EOF
)"

notify-send "Windows on this workspace toggled to floating/tiling"
