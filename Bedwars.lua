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
local MovementTab = Window:Page({ Name = "Movement", Columns = 2, Subtabs = false })
local VisualsTab = Window:Page({ Name = "Visuals", Columns = 2, Subtabs = false })
local SettingsTab = Library:CreateSettingsPage(Window, Watermark, KeybindList)

-- live feature state (written by UI callbacks below)
local S = { KillAura = false, AuraRange = 16, TeamCheck = true, WallCheck = true }

do -- Combat
    local AuraSection = CombatTab:Section({ Name = "Kill Aura", Side = 1 })
    AuraSection:Toggle({ Name = "Enabled", Flag = "KillAura", Default = false, Callback = function(v) S.KillAura = v end })
    AuraSection:Slider({ Name = "Range", Min = 5, Max = 30, Default = 16, Suffix = "st", Decimals = 1, Flag = "AuraRange", Callback = function(v) S.AuraRange = v end })

    local TargetSection = CombatTab:Section({ Name = "Target", Side = 2 })
    TargetSection:Toggle({ Name = "Team Check", Flag = "TeamCheck", Default = true, Callback = function(v) S.TeamCheck = v end })
    TargetSection:Toggle({ Name = "Wall Check", Flag = "WallCheck", Default = true, Callback = function(v) S.WallCheck = v end })
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

getgenv().BW_Lib = Library
print("[BW] thugsense ui + killaura loaded")
