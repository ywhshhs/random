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
-- patch 4: Expand slider 4 -> 6 max, default 2 -> 3
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

-- VW-grade killaura (stolen from Voidware 6872274481.lua). TURN ALSploit Killaura OFF.
-- Upgrades over stock: 0.02s pacing + controller timestamp reset, {value} boxing,
-- reach pull -14 only past 14st, spear double-hit, HitSlow throttle, one target/tick.
getgenv().VW = getgenv().VW or { Killaura = true, Range = 18, HitSlow = 0, WallCheck = true, TeamCheck = true }
local VW = getgenv().VW
task.spawn(function()
    task.wait(5) -- let AlSploit + game controllers load
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local RS = game:GetService("ReplicatedStorage")
    local LP = Players.LocalPlayer
    local Cam = Workspace.CurrentCamera
    local Net = RS:WaitForChild("rbxts_include").node_modules["@rbxts"].net.out._NetManaged
    local SwordHit = Net:WaitForChild("SwordHit")
    local SwingMiss = Net:WaitForChild("SwordSwingMiss")
    -- real SwordController for cooldown reset (best effort; needs debug lib)
    local SwordControl = nil
    pcall(function()
        local knitMod = LP.PlayerScripts.TS.knit
        local setup = require(knitMod).setup
        local KC = debug.getupvalue(setup, 9)
        SwordControl = KC and KC.Controllers and KC.Controllers.SwordController or nil
    end)
    local function attackValue(v) return { value = v } end -- exact VW shape
    local function myHRP() local c = LP.Character return c and c:FindFirstChild("HumanoidRootPart") end
    local function heldSword()
        local c = LP.Character
        local t = c and c:FindFirstChildOfClass("Tool")
        if t and (t.Name:find("sword", 1, true) or t.Name:find("saber", 1, true) or t.Name:find("scythe", 1, true) or t.Name:find("hammer", 1, true) or t.Name:find("katana", 1, true)) then return t end
        local bp = LP:FindFirstChild("Backpack")
        if bp then for _, x in ipairs(bp:GetChildren()) do
            if x:IsA("Tool") and (x.Name:find("sword", 1, true) or x.Name:find("saber", 1, true)) then return x end
        end end
        return t
    end
    local function invInstance(tool)
        if not tool then return nil end
        local inv = RS:FindFirstChild("Inventories")
        local mine = inv and inv:FindFirstChild(LP.Name)
        return (mine and mine:FindFirstChild(tool.Name)) or tool
    end
    local wallP = RaycastParams.new()
    wallP.FilterType = Enum.RaycastFilterType.Exclude
    while true do
        -- defensive clamps (survive raw-table edits bypassing BW.set)
        VW.Range = math.clamp(tonumber(VW.Range) or 18, 5, 30)
        VW.HitSlow = math.clamp(tonumber(VW.HitSlow) or 0, 0, 20)
        VW.MaxTargets = math.clamp(math.floor(tonumber(VW.MaxTargets) or 3), 1, 6)
        if VW.Killaura then
            local ok = pcall(function()
                local h = myHRP()
                if not h then return end
                -- candidates: alive enemies in range (+wall check)
                local cands = {}
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP then
                        if VW.TeamCheck and p.Team ~= nil and LP.Team ~= nil and p.Team == LP.Team then continue end
                        local c = p.Character
                        local hrp = c and c:FindFirstChild("HumanoidRootPart")
                        local hum = c and c:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and hum.Health > 0 then
                            local d = (hrp.Position - h.Position).Magnitude
                            if d <= VW.Range then
                                if VW.WallCheck then
                                    wallP.FilterDescendantsInstances = { LP.Character, c }
                                    if Workspace:Raycast(Cam.CFrame.Position, hrp.Position - Cam.CFrame.Position, wallP) then continue end
                                end
                                table.insert(cands, { c = c, hrp = hrp, d = d, hp = hum.Health })
                            end
                        end
                    end
                end
                if VW.LowHP then
                    table.sort(cands, function(a, b) return a.hp < b.hp end)
                else
                    table.sort(cands, function(a, b) return a.d < b.d end)
                end
                local sword = heldSword()
                local weapon = sword and invInstance(sword) or nil
                if not weapon then return end -- no sword, no packets (never swing empty-handed)
                local hits = 0
                for _, t in ipairs(cands) do
                    if hits >= VW.MaxTargets then break end
                    local root = t.hrp
                    -- face target so the swing story holds together
                    if VW.FaceTarget then
                        pcall(function()
                            h.CFrame = CFrame.new(h.Position, Vector3.new(root.Position.X, h.Position.Y, root.Position.Z))
                        end)
                    end
                    -- VW reach pull: only past 14st, minus 14 (not 14.4)
                    local selfpos = h.Position
                    if VW.Range > 14 and t.d > 14.4 then
                        selfpos = h.Position + (CFrame.lookAt(h.Position, root.Position).LookVector * (t.d - 14))
                    end
                    -- VW pacing: stamp controller to server-now (0.02s floor)
                    if SwordControl then
                        pcall(function()
                            SwordControl.lastAttack = Workspace:GetServerTimeNow()
                            SwordControl.lastSwingServerTime = Workspace:GetServerTimeNow()
                        end)
                    end
                    local dir = (root.Position - Cam.CFrame.Position).Unit
                    SwingMiss:FireServer({ weapon = weapon, chargeRatio = 0 })
                    SwordHit:FireServer({
                        weapon = weapon,
                        chargedAttack = { chargeRatio = 0 },
                        entityInstance = t.c,
                        validate = {
                            raycast = { cameraPosition = attackValue(Cam.CFrame.Position), cursorDirection = attackValue(dir) },
                            targetPosition = attackValue(root.Position),
                            selfPosition = attackValue(selfpos),
                        },
                    })
                    hits += 1
                    -- VW spear double-hit on the first target only
                    if hits == 1 then
                        local bp = LP:FindFirstChild("Backpack")
                        if bp then for _, x in ipairs(bp:GetChildren()) do
                            if x:IsA("Tool") and x.Name:find("spear", 1, true) then
                                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                                if hum then pcall(function() hum:EquipTool(x) end) end
                                SwordHit:FireServer({
                                    weapon = invInstance(x),
                                    chargedAttack = { chargeRatio = 0 },
                                    entityInstance = t.c,
                                    validate = {
                                        raycast = { cameraPosition = attackValue(Cam.CFrame.Position), cursorDirection = attackValue(dir) },
                                        targetPosition = attackValue(root.Position),
                                        selfPosition = attackValue(selfpos),
                                    },
                                })
                                break
                            end
                        end end
                    end
                end
            end)
            if not ok then task.wait(1) end
            task.wait(math.max(0.02, (VW.HitSlow or 0) / 10))
        else
            task.wait(0.25)
        end
    end
end)
-- Scaffold extras: Tower + SafeWalk (AlSploit has neither).
-- getgenv().VW_Scaf = { Tower=false, TowerDelay=0.1, SafeWalk=false, EdgeDist=2.5 }
getgenv().VW_Scaf = getgenv().VW_Scaf or { Tower = false, TowerDelay = 0.1, SafeWalk = false, EdgeDist = 2.5 }
local VWS = getgenv().VW_Scaf
task.spawn(function()
    task.wait(5)
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local RS = game:GetService("ReplicatedStorage")
    local LP = Players.LocalPlayer
    local Net = RS:WaitForChild("rbxts_include").node_modules["@rbxts"].net.out._NetManaged
    local BlockEngine = RS.rbxts_include.node_modules["@easy-games"]["block-engine"].node_modules["@rbxts"].net.out._NetManaged
    local BlockPlacing = BlockEngine:WaitForChild("BlockPlacing")
    local function gridOf(w) return Vector3.new(math.round(w.X / 3), math.round(w.Y / 3), math.round(w.Z / 3)) end
    local function heldBlock()
        local c = LP.Character
        local t = c and c:FindFirstChildOfClass("Tool")
        if t and t.Name:find("wool", 1, true) then return t.Name end
        local bp = LP:FindFirstChild("Backpack")
        if bp then for _, x in ipairs(bp:GetChildren()) do
            if x:IsA("Tool") and x.Name:find("wool", 1, true) then
                local hum = c and c:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum:EquipTool(x) end) end
                return x.Name
            end
        end end
        return t and t.Name or "wool_white"
    end
    local towerCache, lastTower, lastBox = {}, 0, 0
    local lastSafe = nil
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    game:GetService("RunService").Heartbeat:Connect(function()
        local c = LP.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not h or not hum or hum.Health <= 0 then return end
        -- BOX: 3x3 ring (minus center) around feet, stacked boxheight layers
        VWS.BoxHeight = math.clamp(math.floor(tonumber(VWS.BoxHeight) or 2), 1, 3)
        VWS.BoxDelay = math.clamp(tonumber(VWS.BoxDelay) or 0.15, 0.05, 0.5)
        if VWS.Box then
            if tick() - (lastBox or 0) >= VWS.BoxDelay then
                local feet = h.Position - Vector3.new(0, h.Size.Y / 2 + hum.HipHeight + 1, 0)
                local base = gridOf(feet)
                local placed = false
                for layer = 0, VWS.BoxHeight - 1 do
                    for dx = -1, 1 do for dz = -1, 1 do
                        if not (dx == 0 and dz == 0) then -- ring, keep center open
                            local g = base + Vector3.new(dx, layer, dz)
                            local key = g.X .. "," .. g.Y .. "," .. g.Z
                            if not towerCache[key] or tick() - towerCache[key] > 10 then
                                towerCache[key] = tick()
                                pcall(function()
                                    BlockPlacing:InvokeServer({ blockType = heldBlock(), blockData = 0, position = g })
                                end)
                                placed = true
                            end
                        end
                    end end
                end
                if placed then lastBox = tick() end
            end
        end
        -- TOWER: pillar straight up while jumping (grid coords, verified rule)
        VWS.TowerDelay = math.clamp(tonumber(VWS.TowerDelay) or 0.1, 0.03, 0.5)
        VWS.EdgeDist = math.clamp(tonumber(VWS.EdgeDist) or 2.5, 1, 6)
        if VWS.Tower and (hum.Jump or h.AssemblyLinearVelocity.Y > 1) then
            if tick() - lastTower >= VWS.TowerDelay then
                local feet = h.Position - Vector3.new(0, h.Size.Y / 2 + hum.HipHeight * 1.5, 0)
                local g = gridOf(feet)
                local key = g.X .. "," .. g.Y .. "," .. g.Z
                if not towerCache[key] or tick() - towerCache[key] > 5 then
                    towerCache[key] = tick()
                    lastTower = tick()
                    pcall(function()
                        BlockPlacing:InvokeServer({ blockType = heldBlock(), blockData = 0, position = g })
                    end)
                end
            end
        end
        -- SAFEWALK: snap back to last grounded spot when walking off an edge
        rp.FilterDescendantsInstances = { c }
        if hum.FloorMaterial ~= Enum.Material.Air then
            lastSafe = h.CFrame
        elseif VWS.SafeWalk and lastSafe and hum.MoveDirection.Magnitude > 0.1 then
            local ahead = h.Position + hum.MoveDirection * (VWS.EdgeDist or 2.5)
            local downHere = Workspace:Raycast(h.Position, Vector3.new(0, -7, 0), rp)
            local downAhead = Workspace:Raycast(ahead, Vector3.new(0, -7, 0), rp)
            if not downHere and not downAhead then
                h.AssemblyLinearVelocity = Vector3.zero
                c:PivotTo(lastSafe)
            end
        end
    end)
end)
-- Robust config: one schema, validated setters, clamping, save/load.
-- getgenv().BW.show()  -> prints everything
-- getgenv().BW.set("killaura.range", 22) / getgenv().BW.get("scaf.towerdelay")
-- getgenv().BW.reset() / getgenv().BW.save() / getgenv().BW.load()
getgenv().BW = getgenv().BW or {}
local BW = getgenv().BW
local SCHEMA = {
    killaura = { desc = "VW-grade aura (disable AlSploit Killaura)" },
    ["killaura.enabled"]  = { t = "b", d = true },
    ["killaura.range"]    = { t = "n", d = 18, min = 5, max = 30 },
    ["killaura.hitslow"]  = { t = "n", d = 0, min = 0, max = 20 },
    ["killaura.wallcheck"] = { t = "b", d = true },
    ["killaura.teamcheck"] = { t = "b", d = true },
    ["killaura.maxtargets"] = { t = "n", d = 3, min = 1, max = 6 },
    ["killaura.facetarget"] = { t = "b", d = true },
    ["killaura.lowhp"]      = { t = "b", d = false },
    scaf = { desc = "Scaffold extras" },
    ["scaf.tower"]      = { t = "b", d = false },
    ["scaf.towerdelay"] = { t = "n", d = 0.1, min = 0.03, max = 0.5 },
    ["scaf.safewalk"]   = { t = "b", d = false },
    ["scaf.edgedist"]   = { t = "n", d = 2.5, min = 1, max = 6 },
    ["scaf.box"]        = { t = "b", d = false },
    ["scaf.boxheight"]  = { t = "n", d = 2, min = 1, max = 3 },
    ["scaf.boxdelay"]   = { t = "n", d = 0.15, min = 0.05, max = 0.5 },
}
local STORE = {}
local SECMAP = { killaura = { tab = "VW", keys = { enabled = "Killaura", range = "Range", hitslow = "HitSlow", wallcheck = "WallCheck", teamcheck = "TeamCheck", maxtargets = "MaxTargets", facetarget = "FaceTarget", lowhp = "LowHP" } },
                 scaf = { tab = "VW_Scaf", keys = { tower = "Tower", towerdelay = "TowerDelay", safewalk = "SafeWalk", edgedist = "EdgeDist", box = "Box", boxheight = "BoxHeight", boxdelay = "BoxDelay" } } }
local function readLive(sec, key)
    local m = SECMAP[sec]
    local tab = getgenv()[m.tab]
    return tab and tab[m.keys[key]] or nil
end
local function writeLive(sec, key, v)
    local m = SECMAP[sec]
    getgenv()[m.tab] = getgenv()[m.tab] or {}
    getgenv()[m.tab][m.keys[key]] = v
end
local function coerce(rule, v)
    if rule.t == "b" then
        if type(v) == "boolean" then return v end
        if v == 1 or v == "on" or v == "true" then return true end
        if v == 0 or v == "off" or v == "false" then return false end
        return nil
    else
        local n = tonumber(v)
        if not n then return nil end
        return math.clamp(n, rule.min, rule.max)
    end
end
function BW.set(path, v)
    path = tostring(path):lower()
    local rule = SCHEMA[path]
    if not rule or not rule.t then
        local valid = {}
        for k, r in pairs(SCHEMA) do if r.t then table.insert(valid, k) end end
        table.sort(valid)
        print("[BW] unknown option '" .. path .. "'. valid: " .. table.concat(valid, ", "))
        return false
    end
    local cv = coerce(rule, v)
    if cv == nil then
        print("[BW] bad value for '" .. path .. "' (want " .. (rule.t == "b" and "boolean" or ("number " .. rule.min .. "-" .. rule.max)) .. ")")
        return false
    end
    local sec, key = path:match("^([^.]+)%.([^.]+)$")
    STORE[path] = cv
    writeLive(sec, key, cv)
    print("[BW] " .. path .. " = " .. tostring(cv))
    return true
end
function BW.get(path)
    path = tostring(path):lower()
    if STORE[path] ~= nil then return STORE[path] end
    local rule = SCHEMA[path]
    if rule and rule.t then
        local sec, key = path:match("^([^.]+)%.([^.]+)$")
        local lv = readLive(sec, key)
        if lv ~= nil then local cv = coerce(rule, lv) if cv ~= nil then STORE[path] = cv return cv end end
        return rule.d
    end
    return nil
end
function BW.show()
    local keys = {}
    for k, r in pairs(SCHEMA) do if r.t then table.insert(keys, k) end end
    table.sort(keys)
    print("--- BW config ---")
    for _, k in ipairs(keys) do print(string.format("  %-20s = %s", k, tostring(BW.get(k)))) end
end
function BW.reset()
    for k, r in pairs(SCHEMA) do if r.t then BW.set(k, r.d) end end
    print("[BW] defaults restored")
end
local SAVE_FILE = "bw_config.json"
function BW.save()
    local ok, js = pcall(function() return game:GetService("HttpService"):JSONEncode(STORE) end)
    if not ok then print("[BW] save failed: no JSON") return false end
    if writefile then local wok = pcall(writefile, SAVE_FILE, js) print(wok and "[BW] saved" or "[BW] save failed: writefile") return wok end
    print("[BW] save unavailable (no writefile); config lives in getgenv")
    return false
end
function BW.load()
    if not (isfile and readfile) then print("[BW] load unavailable (no isfile/readfile)") return false end
    local ok, has = pcall(isfile, SAVE_FILE)
    if not ok or not has then print("[BW] no save found") return false end
    local ok2, js = pcall(readfile, SAVE_FILE)
    if not ok2 then print("[BW] read failed") return false end
    local ok3, t = pcall(function() return game:GetService("HttpService"):JSONDecode(js) end)
    if not ok3 or type(t) ~= "table" then print("[BW] save corrupted") return false end
    for k, v in pairs(t) do BW.set(k, v) end
    print("[BW] save loaded")
    return true
end
-- seed live tables from schema defaults (first run) and push through validation
for k, r in pairs(SCHEMA) do if r.t then
    local sec, key = k:match("^([^.]+)%.([^.]+)$")
    if readLive(sec, key) == nil then writeLive(sec, key, r.d) else BW.get(k) end
end end
print("[BW] VW-grade killaura injected (disable AlSploit Killaura)")
print("[BW] config ready: getgenv().BW.show()")
