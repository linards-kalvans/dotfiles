-- Port of the three directives hyprland.conf declares itself instead of sourcing:
-- the two colour aliases at :37-38 and the dbus activation-environment exec-once
-- at :64. Hand-written -- hyprlang2lua converts files, and these lines live in the
-- root file that every other module's `source =` came from, so no run of the
-- converter over conf/ would ever have seen them. They were ORPHANED: no task owned
-- them and they would have been silently lost.
--
-- ===================================================================================
-- COLOUR ALIAS CONTRACT  (hyprland.conf:37-38)  -- READ THIS BEFORE WRITING lua/windows/
-- ===================================================================================
-- hyprlang:
--     source = ~/.config/hypr/colors.conf   # matugen-generated $primary, $on_surface, ...
--     $color8  = $primary
--     $color11 = $on_surface
--
-- CONTRACT, in two parts. Part 2 is the one that bites -- this is NOT a rename job.
--
-- PART 1 -- the aliases DISSOLVE AT THE USE SITE. There is no runtime `color8` /
-- `color11` binding anywhere, and this module does not create one. Take the table that
-- Task 5's generated lua/colors.lua returns -- keyed exactly like colors.conf's $vars:
--
--     hyprlang $color8    ->   colors.primary
--     hyprlang $color11   ->   colors.on_surface
--
-- PART 2 -- THE BORDER COLOURS MUST BE RESTRUCTURED, NOT JUST RENAMED. hyprlang2lua
-- lowers a multi-token `col.active_border` into a Lua STRING CONCAT CHAIN of bare
-- globals, and it does so silently: run it on conf/windows/default.conf and it reports
-- `translated=7 passthrough=4 flagged=0 coverage=100.0%`, exit 0, emitting
--
--     active_border = color8 .. " " .. on_primary .. " 90deg",
--
-- Renaming the identifiers in place gives
--
--     active_border = colors.primary .. " " .. colors.on_primary .. " 90deg",
--
-- which is a STRING where Hyprland 0.55 wants a gradient TABLE. Reported by the Task 9
-- reviewer as failing at startup with `gradient color at index {} must be a string` --
-- that literal is present in /usr/bin/Hyprland, confirmed here. The concat chain must be
-- taken apart into the typed gradient form used at /usr/share/hypr/hyprland.lua:93-95:
--     col = { active_border = { colors = { "rgba(...)", "rgba(...)" }, angle = 45 },
--             inactive_border = "rgba(...)" }
-- Note the asymmetry: a SINGLE colour stays a plain string (inactive_border above); only
-- the multi-colour + angle form becomes a table.
--
-- Worked example, conf/windows/default.conf:10 (the live variation):
--     col.active_border = $color8 $on_primary 90deg
-- becomes
--     local colors = require(<module path Task 3 establishes in require-semantics.md>)
--     hl.config({ general = { col = { active_border = {
--         colors = { colors.primary, colors.on_primary }, angle = 90 } } } })
--
-- So conf/windows/border-1.conf:11 (`col.inactive_border = $color8`) needs only the
-- Part 1 rename. Exactly three lines under conf/windows/ need Part 2 as well -- verified
-- with `grep -rn 'col\.\(in\)\?active_border' conf/windows/`:
--     default.conf:10      col.active_border = $color8 $on_primary 90deg
--     glass.conf:10        col.active_border = $color8 $on_primary 90deg
--     transparent.conf:10  col.active_border = rgb(ffffff) $on_primary 90deg
-- The third has no alias in it at all, so it is outside this contract but hits the same
-- concat-chain trap; listed here so Task 6 does not miss it.
--
-- Thirteen files under conf/windows/ consume these two aliases:
--     border-1..4.conf, border-1..4-reverse.conf, gamemode.conf,
--     no-border.conf, no-border-more-gaps.conf   ($color8 and $color11)
--     default.conf, glass.conf                    ($color8 only)
--
-- WHY THIS FORM, and not a runtime alias binding:
--   1. The aliases carry no value of their own -- they are pure renames of two
--      matugen keys. `colors.primary` is no longer than `color8` and says more.
--   2. Binding them here would force this module to require lua/colors.lua, and
--      NEITHER prerequisite exists on disk yet: Task 3 has not run (there is no
--      hypr-migration/require-semantics.md, so the module-path form -- "lua.colors"
--      vs "lua/colors" vs a package.path prefix -- is still undetermined) and Task 5
--      has not run (there is no lua/colors.lua). Hard-coding an unverified require
--      path into a file that is meant to stay inert until Task 11 would plant a
--      load-time failure with no way to test it now.
--   3. Every consumer has to require the colours module anyway for names that were
--      never aliased -- default.conf:10 and glass.conf:10 both use $on_primary
--      directly -- so an alias layer would save nothing.
--
-- TRAP FOR TASK 6: $color8/$color11 are declared HERE, in hyprland.conf, not in the
-- conf/windows/*.conf files. Run hyprlang2lua over those files and it sees the
-- references as undeclared and emits bare Lua identifiers `color8` / `color11`.
-- Its README claims an undeclared $X "surfaces as a clear load-time error" -- MEASURED,
-- IT DOES NOT: conf/windows/default.conf converts at coverage=100.0%, flagged=0, exit 0,
-- with no TODO marker. Those bare identifiers are globals that are nil at runtime, so
-- the border colours break SILENTLY. They must be replaced per Part 1 above, and the
-- gradient lines restructured per Part 2.
--
-- The mapping is also exported below as data, so a checker can assert Task 6's output
-- against it instead of re-reading this comment.

local M = {
    -- hyprlang alias name -> key in the table lua/colors.lua returns.
    color_aliases = {
        color8  = "primary",
        color11 = "on_surface",
    },
}

-- Environment for xdg-desktop-portal-hyprland (hyprland.conf:64).
--
--     exec-once=dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
--
-- LOAD-BEARING. This is what hands xdg-desktop-portal-hyprland the session
-- environment; without it the portal comes up without WAYLAND_DISPLAY and
-- screensharing breaks. It is a 20th exec-once that Task 8 did not count, because
-- Task 8 only walked the three conf/ files.
--
-- Pattern matches lua/autostart.lua: one hl.exec_cmd inside hl.on("hyprland.start").
-- It is kept in its own subscription rather than folded into autostart.lua so the
-- file provenance stays 1:1 with the hyprlang source -- autostart.lua is the port of
-- conf/cursor.conf + conf/autostart.conf + conf/custom.conf, and this line is in
-- none of them. Multiple hl.on("hyprland.start", ...) subscriptions are supported:
-- hl.on returns an HL.EventSubscription handle per call and "hyprland.start" is a
-- documented HL.EventName in /usr/share/hypr/stubs/hl.meta.lua.
--
-- Ordering note: hyprlang runs this at hyprland.conf:64, i.e. AFTER conf/autostart.conf
-- (:43) and BEFORE conf/custom.conf (:74). In the Lua tree the ordering between these
-- two hyprland.start subscriptions is whatever order main.lua requires the modules in;
-- that is main.lua's responsibility (Task 10/11). Nothing here depends on it -- these
-- are independent one-shot spawns -- but requiring toplevel AFTER autostart keeps the
-- observable spawn order closest to the hyprlang tree.
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
end)

return M
