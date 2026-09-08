-- BW (Thugsense/synca UI shell): dark-orange, mobile+PC. Controls only, no features yet.

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/ywhshhs/synca/main/Thugsense/Library.lua"))()

local Window = Library:Window({
    Name = "Bedwars",
    FadeSpeed = 0.25,
})

-- dark orange theme over the default dark base
Library:ChangeTheme("Accent", Color3.fromHex("#ff7a1a"))

local Watermark = Library:Watermark("bedwars ~ " .. os.date("%b %d %Y"))
local KeybindList = Library:KeybindList()
Watermark:SetVisibility(true)
KeybindList:SetVisibility(false)

local CombatTab = Window:Page({ Name = "Combat", Columns = 2, Subtabs = false })
local WorldTab = Window:Page({ Name = "World", Columns = 2, Subtabs = false })
local MovementTab = Window:Page({ Name = "Movement", Columns = 2, Subtabs = false })
local VisualsTab = Window:Page({ Name = "Visuals", Columns = 2, Subtabs = false })
local SettingsTab = Library:CreateSettingsPage(Window, Watermark, KeybindList)

-- live feature state (written by UI callbacks below)
local S = { KillAura = false, AuraRange = 16, TeamCheck = true, WallCheck = true,
    Scaffold = false, PlaceDelay = 0.12, Expand = 2, Tower = false, AutoEquip = true,
    Nuker = false, NukeRadius = 8, NukeDelay = 0.2, BedsOnly = false }

do -- Combat
    local AuraSection = CombatTab:Section({ Name = "Kill Aura", Side = 1 })
    AuraSection:Toggle({ Name = "Enabled", Flag = "KillAura", Default = false, Callback = function(v) S.KillAura = v end })
    AuraSection:Slider({ Name = "Range", Min = 5, Max = 30, Default = 16, Suffix = "st", Decimals = 1, Flag = "AuraRange", Callback = function(v) S.AuraRange = v end })

    local TargetSection = CombatTab:Section({ Name = "Target", Side = 2 })
    TargetSection:Toggle({ Name = "Team Check", Flag = "TeamCheck", Default = true, Callback = function(v) S.TeamCheck = v end })
    TargetSection:Toggle({ Name = "Wall Check", Flag = "WallCheck", Default = true, Callback = function(v) S.WallCheck = v end })
end

do -- World: Scaffold + Nuker (shapes from your solo log)
    local Sc = WorldTab:Section({ Name = "Scaffold", Side = 1 })
    Sc:Toggle({ Name = "Enabled", Flag = "Scaffold", Default = false, Callback = function(v) S.Scaffold = v end })
    Sc:Slider({ Name = "Place Delay", Min = 0.05, Max = 0.5, Default = 0.12, Suffix = "s", Decimals = 2, Flag = "PlaceDelay", Callback = function(v) S.PlaceDelay = v end })
    Sc:Slider({ Name = "Expand", Min = 1, Max = 4, Default = 2, Suffix = "", Decimals = 0, Flag = "Expand", Callback = function(v) S.Expand = v end })
    Sc:Toggle({ Name = "Tower Mode", Flag = "Tower", Default = false, Callback = function(v) S.Tower = v end })
    Sc:Toggle({ Name = "Auto Equip Blocks", Flag = "AutoEquip", Default = true, Callback = function(v) S.AutoEquip = v end })

    local Nk = WorldTab:Section({ Name = "Nuker", Side = 2 })
    Nk:Toggle({ Name = "Enabled", Flag = "Nuker", Default = false, Callback = function(v) S.Nuker = v end })
    Nk:Slider({ Name = "Radius", Min = 3, Max = 14, Default = 8, Suffix = "st", Decimals = 0, Flag = "NukeRadius", Callback = function(v) S.NukeRadius = v end })
    Nk:Slider({ Name = "Hit Delay", Min = 0.05, Max = 1, Default = 0.2, Suffix = "s", Decimals = 2, Flag = "NukeDelay", Callback = function(v) S.NukeDelay = v end })
    Nk:Toggle({ Name = "Beds Only", Flag = "BedsOnly", Default = false, Callback = function(v) S.BedsOnly = v end })
end

do -- Movement (demo wiring)
    local FlySection = MovementTab:Section({ Name = "Fly", Side = 1 })
    FlySection:Toggle({ Name = "Enabled", Flag = "Fly", Default = false, Callback = function(v) print("Fly", v) end })
    FlySection:Slider({ Name = "Speed", Min = 10, Max = 150, Default = 50, Suffix = "st/s", Decimals = 0, Flag = "FlySpeed", Callback = function(v) print("FlySpeed", v) end })
end

do -- Visuals (demo wiring)
    local EspSection = VisualsTab:Section({ Name = "ESP", Side = 1 })
    EspSection:Toggle({ Name = "Enabled", Flag = "ESP", Default = false, Callback = function(v) print("ESP", v) end })
    :Colorpicker({ Name = "ESP Color", Flag = "EspColor", Default = Color3.fromHex("#ff7a1a"), Callback = function(v) print("EspColor", v) end })
end

-- KillAura: legit-story hits (your log) + leak structure (validate block, 0.294s)
-- Solo log had no SwordHit to copy (no enemies), so hit shape comes from AlSploit:
-- SwordHit:FireServer({ weapon, chargedAttack, entityInstance, validate={raycast, target, self} })
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Net = ReplicatedStorage:WaitForChild("rbxts_include").node_modules["@rbxts"].net.out._NetManaged
local SwordHit = Net:WaitForChild("SwordHit")
local SwordSwingMiss = Net:WaitForChild("SwordSwingMiss")

local function myHRP() local c = LocalPlayer.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function aliveChar(plr)
    local c = plr and plr.Character
    if not c then return nil end
    local h = c:FindFirstChild("HumanoidRootPart")
    local hum = c:FindFirstChildOfClass("Humanoid")
    if h and hum and hum.Health > 0 then return c, h end
    return nil
end
local function isMate(plr)
    if not S.TeamCheck then return false end
    -- Bedwars teams: same Team object, or same bed/team attribute
    if plr.Team ~= nil and LocalPlayer.Team ~= nil and plr.Team == LocalPlayer.Team then return true end
    return false
end
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude
local function visible(fromPos, targetChar, targetPart)
    wallParams.FilterDescendantsInstances = { LocalPlayer.Character, targetChar }
    return Workspace:Raycast(fromPos, targetPart.Position - fromPos, wallParams) == nil
end
local function resolveWeapon()
    local c = LocalPlayer.Character
    local tool = c and c:FindFirstChildOfClass("Tool")
    local inv = ReplicatedStorage:FindFirstChild("Inventories")
    local mine = inv and inv:FindFirstChild(LocalPlayer.Name)
    -- your log: weapon = Inventories[you].wood_sword (inventory instance, not the tool)
    if tool and mine then
        local m = mine:FindFirstChild(tool.Name)
        if m then return m end
    end
    return tool
end

local lastHit = 0
task.spawn(function()
    while true do
        task.wait(0.05)
        if S.KillAura then
            local h = myHRP()
            if h then
                local best, bestD, bestPart = nil, S.AuraRange, nil
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and not isMate(p) then
                        local c, hrp = aliveChar(p)
                        if c then
                            local part = c:FindFirstChild("Head") or hrp
                            local d = (part.Position - h.Position).Magnitude
                            if d <= bestD then
                                local eye = Camera.CFrame.Position
                                if not S.WallCheck or visible(eye, c, part) then
                                    best, bestD, bestPart = c, d, part
                                end
                            end
                        end
                    end
                end
                if best and tick() - lastHit >= 0.294 then
                    lastHit = tick()
                    local weapon = resolveWeapon()
                    if weapon then
                        local headPos = bestPart.Position
                        local eye = h.Position + Vector3.new(0, 1.5, 0)
                        -- leak reach math: pull self pos toward target past 14.4st
                        local look = CFrame.lookAt(h.Position, headPos).LookVector
                        local selfPos = h.Position + look * math.max(bestD - 14.4, 0)
                        local dir = (headPos - Camera.CFrame.Position).Unit
                        pcall(function()
                            SwordSwingMiss:FireServer({ weapon = weapon, chargeRatio = 0 })
                            SwordHit:FireServer({
                                weapon = weapon,
                                chargedAttack = { chargeRatio = 0 },
                                entityInstance = best,
                                validate = {
                                    raycast = { cameraPosition = { value = Camera.CFrame.Position }, cursorDirection = { value = dir } },
                                    targetPosition = { value = headPos },
                                    selfPosition = { value = selfPos },
                                },
                            })
                        end)
                    end
                end
            end
        end
    end
end)

-- Scaffold + Nuker engine
-- STOLEN from AlSploit: scaffold uses BlockPlacingRemote {blockType, blockData, position}
-- (NOT PlaceBlock -- that needs full mouseBlockInfo and gets rejected)
local BlockNet = ReplicatedStorage.rbxts_include.node_modules["@easy-games"]["block-engine"].node_modules["@rbxts"].net.out._NetManaged
local BlockPlacing = BlockNet:WaitForChild("BlockPlacing")
local DamageBlock = BlockNet:WaitForChild("DamageBlock")

local GRID = 3
local function toGrid(w) return Vector3.new(math.round(w.X / GRID), math.round(w.Y / GRID), math.round(w.Z / GRID)) end
local function snap3(w) local g = toGrid(w) return Vector3.new(g.X * GRID, g.Y * GRID, g.Z * GRID) end
local placedAt = {} -- worldPosKey -> time (don't refire placed cells)
local lastPlaced = nil

local TOOL_JUNK = { "sword", "pickaxe", "axe", "shears", "bow", "hammer", "scythe", "saber", "katana", "balloon", "pearl", "gadget", "kit" }
local BLOCK_HINT = { "wool", "ceramic", "glass", "stone", "obsidian", "blastproof", "plank" }
local function looksBlockTool(name)
    local n = name:lower()
    for _, j in ipairs(TOOL_JUNK) do if n:find(j, 1, true) then return false end end
    for _, b in ipairs(BLOCK_HINT) do if n:find(b, 1, true) then return true end end
    return false -- unknown: don't touch
end
local function ensureBlocks()
    local c = LocalPlayer.Character
    if not c then return false end
    local held = c:FindFirstChildOfClass("Tool")
    if held and looksBlockTool(held.Name) then return true end
    if not S.AutoEquip then return held ~= nil end
    local hum = c:FindFirstChildOfClass("Humanoid")
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if hum and bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and looksBlockTool(t.Name) then
                pcall(function() hum:EquipTool(t) end)
                task.wait(0.15)
                return true
            end
        end
    end
    return false
end

-- AlSploit scaffold math: ahead cells at feet level, snapped to 3-grid, minimal args.
-- feetBase = HRP - (HRP.Size.Y/2 + HipHeight*1.5); cell_i = feetBase + LookVector*i
task.spawn(function()
    local lastPlace = 0
    while true do
        task.wait(0.03)
        if S.Scaffold then
            local c = LocalPlayer.Character
            local h = myHRP()
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            local effDelay = S.Tower and math.min(S.PlaceDelay, 0.05) or S.PlaceDelay
            if h and hum and tick() - lastPlace >= effDelay and ensureBlocks() then
                local tool = c:FindFirstChildOfClass("Tool")
                local blockType = tool and tool.Name or "wool_white"
                local feetBase = h.Position - Vector3.new(0, h.Size.Y / 2 + hum.HipHeight * 1.5, 0)
                local look = h.CFrame.LookVector
                for i = 1, (S.Expand or 2) * 3 do
                    local want = feetBase + Vector3.new(look.X * i, 0, look.Z * i)
                    local pos = snap3(want)
                    local key = pos.X .. "," .. pos.Y .. "," .. pos.Z
                    if not placedAt[key] or tick() - placedAt[key] > 5 then
                        pcall(function()
                            BlockPlacing:InvokeServer({ blockType = blockType, blockData = 0, position = pos })
                        end)
                        placedAt[key] = tick()
                        lastPlaced = pos
                    end
                end
                lastPlace = tick()
            end
        else
            lastPlaced = nil
        end
    end
end)

-- Nuker: 3-stud cubes (+ bed parts) in radius, Invoke capped per tick
local nukeCache, nukeScan = {}, 0
local function rescanBlocks()
    local found = {}
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("BasePart") then
            local s = d.Size
            local isCube = math.abs(s.X - 3) < 0.2 and math.abs(s.Y - 3) < 0.2 and math.abs(s.Z - 3) < 0.2
            local nm = (d.Name .. " " .. (d.Parent and d.Parent.Name or "")):lower()
            if isCube or nm:find("bed", 1, true) then
                table.insert(found, { part = d, bed = nm:find("bed", 1, true) ~= nil })
                if #found > 400 then break end
            end
        end
    end
    nukeCache, nukeScan = found, os.clock()
end
task.spawn(function()
    while true do
        task.wait(0.05)
        if S.Nuker then
            local h = myHRP()
            if h then
                if os.clock() - nukeScan > 1 then rescanBlocks() end
                local sent = 0
                for _, e in ipairs(nukeCache) do
                    if sent >= 3 then break end
                    local p = e.part
                    if p and p.Parent then
                        if (not S.BedsOnly or e.bed) and (p.Position - h.Position).Magnitude <= S.NukeRadius then
                            local g = toGrid(p.Position)
                            pcall(function()
                                DamageBlock:InvokeServer({
                                    blockRef = { blockPosition = g },
                                    hitPosition = p.Position,
                                    hitNormal = Vector3.yAxis,
                                })
                            end)
                            sent += 1
                        end
                    end
                end
                if sent > 0 then task.wait(S.NukeDelay) end
            end
        end
    end
end)

getgenv().BW_Lib = Library
print("[BW] thugsense ui + killaura + scaffold + nuker loaded")
