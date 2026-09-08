-- BW: AlSploit bootstrap with compatibility patches.
-- Why it errored through loadstring:
--  1. Line 13 uses Luau type annotations (String: string) -> most executors'
--     loadstring compiles strict and dies on ':'. Stripped below.
--  2. The stray `if false` dead block at the top is removed for cleanliness.
--  3. On mobile executors getexecutorname()/http_request may not exist ->
--     safe shims so the executor check can't nil-call.

getexecutorname = getexecutorname or function() return "Unknown" end
if not (http_request or request or httprequest) then
    local function dummyHttp(_)
        return { Success = false, Body = "{}" }
    end
    http_request = dummyHttp
end

local src = game:HttpGet("https://raw.githubusercontent.com/ywhshhs/sss/main/alsploitLEEEEEAK.lua")
-- fetch guard: a failed/blocked fetch returns an error page, never patch that
assert(type(src) == "string" and #src > 100000 and src:find("Scaffold", 1, true),
    "[BW] fetch failed (got " .. tostring(src and #src) .. " bytes, expected 400k+ AlSploit source). Check network/executor HTTP.")

-- patch 1: drop the dead `if false` block at the top
src = src:gsub("^if false%s+then%s+local _unused = 0%s+end%s*", "", 1)
-- patch 2: strip the only type-annotated signature in the file
src = src:gsub("xorEncode%(String: string, key: string%)", "xorEncode(String, key)")
-- patch 3: scaffold visualizer waits 0.15s per cell -> 0.03s (both branches)
local nviz
src, nviz = src:gsub("task%.wait%(0%.15%)", "task.wait(0.03)")
print("[BW] visualizer-wait patches:", nviz)
-- cosmetic patches must NEVER brick loading (upstream edits change whitespace).
-- Miss = warn + run unpatched, not assert.
local function spliceOnce(hay, needle, repl, tag)
    local a, b = hay:find(needle, 1, true) -- plain find, no patterns
    if not a then
        warn("[BW] cosmetic patch skipped (upstream changed): " .. tag)
        return hay
    end
    return hay:sub(1, a - 1) .. repl .. hay:sub(b + 1)
end
-- patch 4: Expand slider 4 -> 6 max, default 2 -> 3
src = spliceOnce(src,
    ", MaximumValue = 4,\nDefaultValue = 2 }",
    ", MaximumValue = 6,\nDefaultValue = 3 }", "expand")
-- patch 5: non-legit scaffold runs cells in parallel task.spawns (race order).
-- Run them inline instead: strict i=1..N order = closest block ALWAYS first.
src = spliceOnce(src,
    "for i = 1, (Config.Scaffold.Expand.Value * 3)  do\n\t\t\t\t\ttask.spawn(function()\n",
    "for i = 1, (Config.Scaffold.Expand.Value * 3)  do\n", "spawn-head")
src = spliceOnce(src,
    "position = _cjyccGXLoFx})\n\t\t\t\t\t\tend\n\n\t\t\t\t\tend)\n\t\t\t\tend",
    "position = _cjyccGXLoFx})\n\t\t\t\t\t\tend\n\t\t\t\tend", "spawn-tail")
print("[BW] expand+scaffold-order patched")
-- patch 6: Nuker was 10 blocks per ~1.5s (0.5s cycle + 0.1s each).
-- Cycle 0.05s, per-block 0.02s, breaker cooldown 0.1 -> 0.01.
src = spliceOnce(src,
    "\trepeat task.wait(0.5)\n\t\t\t\tfor i = 1, (3+7)",
    "\trepeat task.wait(0.05)\n\t\t\t\tfor i = 1, (3+7)", "nuke-cycle")
src = spliceOnce(src,
    "task.wait(0.1) _lDKOvFsDaFrSRiVYLx()",
    "task.wait(0.02) _lDKOvFsDaFrSRiVYLx()", "nuke-tick")
src = spliceOnce(src,
    "blockBreaker:setCooldown(0.1) uiPadding.BlockBreakController.blockBreaker:setRange((10+20))",
    "blockBreaker:setCooldown(0.01) uiPadding.BlockBreakController.blockBreaker:setRange((10+20))", "nuke-cooldown")
-- patch 7: Killaura pacing 0.294s hit / 0.111s swing windows -> 0.05s.
-- (Voidware runs 0.02s on the same validate story; 0.05 keeps margin.)
src = spliceOnce(src, ") < 0.1111111111111111", ") < 0.05", "aura-swing")
src = spliceOnce(src, ") < 0.294 +", ") < 0.05 +", "aura-hit")
-- patch 8: reach pull 14.4 -> 14 (Voidware value; legit-range behavior unchanged)
src = spliceOnce(src, "EntityDistance - 14.39999", "EntityDistance - 14", "reach")
-- patch 9: BlockVisualizer defaults ON (parts+tweens+lights per cell = lag).
-- Default it OFF; re-enable in UI if wanted.
src = spliceOnce(src,
    "Name = 'BlockVisualizer', Function = function()\nend\n\n, DefaultValue = true",
    "Name = 'BlockVisualizer', Function = function()\nend\n\n, DefaultValue = false", "viz-default")
-- patch 10: PickupItemRange loop 0.1s + 0.3s per-item vacuum delay -> 0.03/0.05s
src = spliceOnce(src,
    "Name = 'PickupItemRange', Function = function()\n\t\trepeat task.wait(0.1)",
    "Name = 'PickupItemRange', Function = function()\n\t\trepeat task.wait(0.03)", "pickup-loop")
src = spliceOnce(src,
    "task.wait(0.3) v.CFrame = CFrame.new(",
    "task.wait(0.05) v.CFrame = CFrame.new(", "pickup-item")
print("[BW] nuker/aura/reach/viz/pickup patched")

assert(not src:find("String: string", 1, true), "[BW] annotation strip failed")

local fn, err = loadstring(src)
if not fn then
    error("[BW] AlSploit failed to compile: " .. tostring(err))
end
print("[BW] AlSploit compiled, running...")
task.spawn(function()
    pcall(fn)
    -- scaffold was server/client-throttled by BLOCK_PLACE_CPS: pin it open.
    -- (same thing its NoPlacementCPS toggle does; we just enforce it)
    task.wait(3)
    while true do
        pcall(function()
            local m = require(game:GetService("ReplicatedStorage").TS["shared-constants"])
            local t = m.CpsConstants or m.CPSConstants or m
            if t and t.BLOCK_PLACE_CPS ~= nil and t.BLOCK_PLACE_CPS ~= math.huge then
                t.BLOCK_PLACE_CPS = math.huge
            end
        end)
        task.wait(5)
    end
end)
print("[BW] bootstrap done")
