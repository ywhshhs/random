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
        if VW.Killaura then
            local ok = pcall(function()
                local h = myHRP()
                if not h then return end
                -- nearest alive enemy
                local best, bestD = nil, VW.Range
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP then
                        if VW.TeamCheck and p.Team ~= nil and LP.Team ~= nil and p.Team == LP.Team then continue end
                        local c = p.Character
                        local hrp = c and c:FindFirstChild("HumanoidRootPart")
                        local hum = c and c:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and hum.Health > 0 then
                            local d = (hrp.Position - h.Position).Magnitude
                            if d <= bestD then
                                if VW.WallCheck then
                                    wallP.FilterDescendantsInstances = { LP.Character, c }
                                    if Workspace:Raycast(Cam.CFrame.Position, hrp.Position - Cam.CFrame.Position, wallP) then continue end
                                end
                                best, bestD = c, d
                            end
                        end
                    end
                end
                if best then
                    local root = best:FindFirstChild("HumanoidRootPart")
                    local sword = heldSword()
                    if root and sword then
                        local weapon = invInstance(sword)
                        -- VW reach pull: only past 14st, minus 14 (not 14.4)
                        local selfpos = h.Position
                        if VW.Range > 14 and bestD > 14.4 then
                            selfpos = h.Position + (CFrame.lookAt(h.Position, root.Position).LookVector * (bestD - 14))
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
                            entityInstance = best,
                            validate = {
                                raycast = { cameraPosition = attackValue(Cam.CFrame.Position), cursorDirection = attackValue(dir) },
                                targetPosition = attackValue(root.Position),
                                selfPosition = attackValue(selfpos),
                            },
                        })
                        -- VW spear double-hit
                        local bp = LP:FindFirstChild("Backpack")
                        if bp then for _, x in ipairs(bp:GetChildren()) do
                            if x:IsA("Tool") and x.Name:find("spear", 1, true) then
                                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                                if hum then pcall(function() hum:EquipTool(x) end) end
                                SwordHit:FireServer({
                                    weapon = invInstance(x),
                                    chargedAttack = { chargeRatio = 0 },
                                    entityInstance = best,
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
    local towerCache, lastTower = {}, 0
    local lastSafe = nil
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    game:GetService("RunService").Heartbeat:Connect(function()
        local c = LP.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not h or not hum or hum.Health <= 0 then return end
        -- TOWER: pillar straight up while jumping (grid coords, verified rule)
        if VWS.Tower and (hum.Jump or h.AssemblyLinearVelocity.Y > 1) then
            if tick() - lastTower >= (VWS.TowerDelay or 0.1) then
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
print("[BW] VW-grade killaura injected (disable AlSploit Killaura)")
print("[BW] scaffold extras loaded: getgenv().VW_Scaf")
