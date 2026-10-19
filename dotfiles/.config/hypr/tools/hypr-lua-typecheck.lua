-- Load a Hyprland Lua config module under a fake `hl` table, flatten every
-- hl.config({...}) call to dotted keys, and print "key<TAB>luatype" per line.
--
-- Exists because a name-only API check passes a wrongly-TYPED value. Task 6
-- emitted `decoration.shadow.color = 0x66000000` as a Lua number where the API
-- declares string; Hyprland's lua_isstring gate returns true for numbers, so it
-- reaches parseColor as "1711276032" and is rejected at runtime with
-- `invalid color`. Nothing in the toolchain caught it: it parses, it loads, the
-- converter reports full coverage, and the audit's colour check only inspected
-- border keys.
local out = {}

local function flatten(tbl, prefix)
    for k, v in pairs(tbl) do
        if type(k) == "string" then
            local key = prefix and (prefix .. "." .. k) or k
            if type(v) == "table" then
                -- An array (gradient colours) is a value, not a namespace.
                if #v > 0 then out[#out+1] = key .. "\ttable" else flatten(v, key) end
            else
                out[#out+1] = key .. "\t" .. type(v)
            end
        end
    end
end

-- noop must return ITSELF from both __index and __call so arbitrarily deep
-- chains work: hl.dsp.window.close() is index, index, index, call.
local noop = setmetatable({}, {})
getmetatable(noop).__index = function() return noop end
getmetatable(noop).__call  = function() return noop end
-- Every hl.* member resolves to `noop`, which is BOTH callable and indexable --
-- hl.bind(...) and hl.dsp.window.close() must both work. Returning a bare
-- function here breaks the latter.
_G.hl = setmetatable({
    config = function(t) if type(t) == "table" then flatten(t, nil) end end,
}, {
    __index = function() return noop end,
})

-- Hyprland resolves require() relative to the directory holding hyprland.lua
-- (established by the Task 3 probe: require("lua.probe") loads lua/probe.lua).
-- A standalone `lua` has no such root, so set it here or every module that
-- requires lua.colors fails to load for harness reasons rather than real ones.
local root = os.getenv("HOME") .. "/.config/hypr"
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local path = ...
local chunk, err = loadfile(path)
if not chunk then io.stderr:write("LOADERR\t" .. tostring(err) .. "\n"); os.exit(2) end
local ok, rerr = pcall(chunk)
if not ok then io.stderr:write("RUNERR\t" .. tostring(rerr) .. "\n"); os.exit(3) end
for _, line in ipairs(out) do print(line) end
