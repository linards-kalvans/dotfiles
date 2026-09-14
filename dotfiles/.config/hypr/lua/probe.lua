-- Probe module. gaps_out = 77 is unique: the real config uses 2, Hyprland's
-- default is 20, so the value alone distinguishes "require worked" from
-- "require failed but main.lua loaded" from "neither loaded".
hl.config({ general = { gaps_out = 77 } })
