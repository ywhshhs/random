--[[ 
    Zone Defense - Zombie Helper
    Built for your game where zombies are NOT Humanoids / NOT NPCs
    and Players show as enemies when allied, so Player-check aimbots fail.

    What we learned from your Folder_ai dump (357 zombies):
    - All zombies live under `ai` folder (ObjectCache = templates, ignore those)
    - Zombie Models: normalZombie, normalRedZombie, normalBlueZombie, crawlingZombie,
      speedZombie, blueMetalZombie, skeletonZombie, cyclopsZombie, bigCrawlingZombie,
      exploderZombie, armoredZombie, tankZombie, bigBlackZombie, treasureZombie,
      redSlateZombie, yellowSlateZombie, slimeZombie, halfSkeletonZombie,
      ghostZombie, spiderZombie
    - NO Humanoid. Custom health via Attributes:
        mainCrit = "head" , mainTorsoName = "torso"
        live zombies also have: clientHealth, maxHealth, simZombieId
      Templates have NO clientHealth + are stored at 16,777,216 studs away.
    - Parts: "torso" , "head" , HumanoidRootPart (invisible), healthBar BillboardGui
    - AnimationController, NOT Humanoid Animator

    So this script NEVER touches Players. It only targets Models with
    GetAttribute("mainCrit") / "mainTorsoName" + a real position.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Config = {
    Enabled = true,

    -- Zone defense: define zone center. Auto-set to your character on load,
    -- or set manually. Anything entering ZoneRadius gets priority.
    ZoneCenter = nil, -- Vector3, nil = use position when script started
    ZoneRadius = 60,
    DefendZone = false, -- auto-walk/teleport back to zone if you leave it

    -- Combat (guns need big range, your log shows 100+ stud shots)
    KillAura = false,
    KillAuraRange = 200, -- studs from character (guns). Set 25 if melee.
    AttackDelay = 0.12,
    TargetPriority = "Closest", -- "Closest" | "LowestHP" | "HighestHP" | "TreasureFirst" | "ExploderFirst"
    AimAt = "head", -- uses mainCrit attribute, fallback to "head"/"torso"
    HitboxExpand = false,
    HitboxSize = 10, -- expand torso/head size for easy hits

    -- Aimbot (camera lock, for guns/melee)
    Aimbot = false,
    AimbotFOV = 200, -- pixels from screen center
    AimKey = Enum.KeyCode.C, -- hold to lock

    -- ESP
    ESP = false,
    ESP_MaxDistance = 1000,
    ShowHealth = true,
    ShowDistance = true,

    -- Safety
    IgnoreExploder = false, -- true = never auto-target exploderZombie (it explodes)
    AttackPlayersNever = true, -- forced true, do not turn off
}

if not Config.ZoneCenter and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
    Config.ZoneCenter = LocalPlayer.Character.HumanoidRootPart.Position
end

-- // ZOMBIE DETECTION (the important part) //

local ZOMBIE_NAMES = {
    normalZombie=true, normalRedZombie=true, normalBlueZombie=true,
    crawlingZombie=true, speedZombie=true, blueMetalZombie=true,
    skeletonZombie=true, cyclopsZombie=true, bigCrawlingZombie=true,
    exploderZombie=true, armoredZombie=true, tankZombie=true,
    bigBlackZombie=true, treasureZombie=true, redSlateZombie=true,
    yellowSlateZombie=true, slimeZombie=true, halfSkeletonZombie=true,
    ghostZombie=true, spiderZombie=true,
}

-- Find zombie containers (live, not templates)
local function getZombieContainers()
    local out = {}
    -- 1. Known folder: Workspace.ai
    local ai = Workspace:FindFirstChild("ai")
    if ai then table.insert(out, ai) end
    -- 2. Fallbacks if dev renamed it
    for _, n in ipairs({"Enemies","Zombies","Mobs","NPCs","Wave"}) do
        local f = Workspace:FindFirstChild(n)
        if f and f ~= ai then table.insert(out, f) end
    end
    return out
end

local function isTemplatePosition(pos)
    -- Templates are stored at 16,777,216 studs (seen in your dump)
    return math.abs(pos.X) > 100000 or math.abs(pos.Y) > 100000 or math.abs(pos.Z) > 100000
end

local function isZombie(model)
    if not model or not model:IsA("Model") then return false end
    -- NEVER target players / player characters
    if Players:GetPlayerFromCharacter(model) then return false end
    if model:FindFirstChildOfClass("Humanoid") and Players:GetPlayerFromCharacter(model) ~= nil then
        return false
    end
    -- Real check: custom attributes from your dump
    local mainCrit = model:GetAttribute("mainCrit")
    local mainTorso = model:GetAttribute("mainTorsoName")
    if mainCrit ~= nil or mainTorso ~= nil then
        -- exclude ObjectCache templates: no health + far away
        local hrp = model:FindFirstChild("HumanoidRootPart")
        local torso = model:FindFirstChild(mainTorso or "torso") or model:FindFirstChild("torso")
        local pos = hrp and hrp.Position or (torso and torso.Position)
        if pos and isTemplatePosition(pos) then return false end
        -- must have a health indicator (live spawn has clientHealth or healthBar)
        local hp = model:GetAttribute("clientHealth")
        local maxHp = model:GetAttribute("maxHealth")
        if hp ~= nil then
            if hp <= 0 then return false end -- dead
        else
            -- no attribute yet (just spawned) -> allow if it has visible parts + healthBar
            if not model:FindFirstChild("healthBar", true) and not torso then return false end
        end
        if maxHp == nil and not model:FindFirstChild("healthBar", true) then
            -- likely a template inside ObjectCache folder, skip
            if model:IsDescendantOf(Workspace:FindFirstChild("ai") and Workspace.ai:FindFirstChild("ObjectCache") or Workspace) then
                -- check ancestor name
                local p = model.Parent
                while p do
                    if p.Name == "ObjectCache" then return false end
                    p = p.Parent
                end
            end
        end
        return true
    end
    -- Fallback: name match + has torso/head + healthBar, but no Humanoid-player
    if ZOMBIE_NAMES[model.Name] then
        if model:FindFirstChild("torso") and model:FindFirstChild("head") then
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if hrp and isTemplatePosition(hrp.Position) then return false end
            return true
        end
    end
    return false
end

local function getAimPart(model)
    local critName = model:GetAttribute("mainCrit") or Config.AimAt or "head"
    local torsoName = model:GetAttribute("mainTorsoName") or "torso"
    return model:FindFirstChild(critName) or model:FindFirstChild("head")
        or model:FindFirstChild(torsoName) or model:FindFirstChild("torso")
        or model:FindFirstChild("HumanoidRootPart")
end

local function getHealth(model)
    local hp = model:GetAttribute("clientHealth")
    local maxHp = model:GetAttribute("maxHealth")
    if hp and maxHp then return hp, maxHp end
    return nil, nil
end

local function getAllZombies()
    local list = {}
    -- Fast path: if ai folder exists, use GetDescendants filtered
    local containers = getZombieContainers()
    if #containers > 0 then
        for _, c in ipairs(containers) do
            for _, d in ipairs(c:GetDescendants()) do
                if d:IsA("Model") and isZombie(d) then
                    -- avoid duplicates (descendants walk hits nested models)
                    table.insert(list, d)
                end
            end
        end
        -- dedupe (nested models like crit parts are MeshParts not Models, so usually fine)
        local seen, uniq = {}, {}
        for _, z in ipairs(list) do
            if not seen[z] then seen[z]=true table.insert(uniq,z) end
            if #uniq > 600 then break end
        end
        return uniq
    end
    -- Full workspace fallback (slower)
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Model") and isZombie(d) then
            table.insert(list, d)
            if #list > 600 then break end
        end
    end
    return list
end

local function myHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function sortTargets(list)
    local hrp = myHRP()
    local hp = hrp and hrp.Position
    local mode = Config.TargetPriority
    table.sort(list, function(a,b)
        local pa, pb = getAimPart(a), getAimPart(b)
        if not pa or not pb then return false end
        -- priority overrides
        if mode == "TreasureFirst" then
            local ta, tb = (a.Name=="treasureZombie"), (b.Name=="treasureZombie")
            if ta ~= tb then return ta end
        elseif mode == "ExploderFirst" then
            local ea, eb = (a.Name=="exploderZombie"), (b.Name=="exploderZombie")
            if ea ~= eb then return ea end
        elseif mode == "LowestHP" or mode == "HighestHP" then
            local ha = getHealth(a) or math.huge
            local hb = getHealth(b) or math.huge
            if ha ~= hb then
                if mode=="LowestHP" then return ha < hb else return ha > hb end
            end
        end
        -- zone members first
        if Config.ZoneCenter then
            local daZone = (pa.Position - Config.ZoneCenter).Magnitude
            local dbZone = (pb.Position - Config.ZoneCenter).Magnitude
            local aIn = daZone <= Config.ZoneRadius
            local bIn = dbZone <= Config.ZoneRadius
            if aIn ~= bIn then return aIn end
        end
        -- default closest to player
        if hp then
            return (pa.Position-hp).Magnitude < (pb.Position-hp).Magnitude
        end
        return false
    end)
    return list
end

local function getBestTarget(maxRange, fovCheck)
    local zombies = getAllZombies()
    if #zombies == 0 then return nil end
    if Config.IgnoreExploder then
        local f = {}
        for _,z in ipairs(zombies) do if z.Name~="exploderZombie" then table.insert(f,z) end end
        zombies = f
    end
    sortTargets(zombies)
    local hrp = myHRP()
    for _, z in ipairs(zombies) do
        local part = getAimPart(z)
        if part then
            if maxRange and hrp then
                if (part.Position - hrp.Position).Magnitude > maxRange then continue end
            end
            if fovCheck then
                local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                if not onScreen then continue end
                local d = (Vector2.new(sp.X,sp.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                if d > Config.AimbotFOV then continue end
            end
            return z, part
        end
    end
    return nil
end

-- // ATTACK via shootBullet (from your 06_20_58Z.log) //
-- shootBullet args (10 total, from log):
--   1 spread CFrame (0,0,0 + random rot), 2 muzzle CFrame (gun pos -> aim dir),
--   3 nil, 4 {{ zombieId, true, rand, bulletIndex, headFlag }},
--   5 Tool, 6 {}, 7 {{ zombieId, {{{false,"goldenLight"}}} }}, 8-10 nil
-- zombieId = target:GetAttribute("simZombieId") (matches server spawn id)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shootEvent = nil
pcall(function()
    shootEvent = ReplicatedStorage:WaitForChild("events", 5):WaitForChild("shootBullet", 5)
end)
if not shootEvent then
    pcall(function() shootEvent = ReplicatedStorage.events.shootBullet end)
end

local bulletIndex = 22 -- observed in log: increments 22,23,24... server may validate order
local function getTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    local t = char:FindFirstChildOfClass("Tool")
    if t then return t end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then return bp:FindFirstChildOfClass("Tool") end
    return nil
end
local function getMuzzlePos(tool)
    local hrp = myHRP()
    if tool then
        -- try Barrel / Handle / gun tip like renderBullet uses (rayStorage Barrel)
        local barrel = tool:FindFirstChild("Barrel", true) or tool:FindFirstChild("Handle") or tool:FindFirstChild("GunTip", true)
        if barrel and barrel:IsA("BasePart") then return barrel.Position end
        -- try model primary part
        if tool:IsA("Model") and tool.PrimaryPart then return tool.PrimaryPart.Position end
    end
    if hrp then return hrp.Position + Vector3.new(0, 1.5, 0) end
    return Camera and Camera.CFrame.Position or Vector3.new()
end

local function doAttack(target, part)
    local char = LocalPlayer.Character
    if not char then return end
    local tool = getTool()
    -- always activate tool too (fires animations / reload logic)
    if tool and tool.Parent == char then
        pcall(function() tool:Activate() end)
    end
    if not shootEvent or not target or not part then return end
    local zid = target:GetAttribute("simZombieId")
    if not zid then return end -- can't hit without server id (template / not replicated yet)
    bulletIndex += 1
    local muzzle = getMuzzlePos(tool)
    local aimCF = CFrame.new(muzzle, part.Position)
    local spreadCF = CFrame.new() -- identity spread = perfect accuracy
    local ok, err = pcall(function()
        shootEvent:FireServer(
            spreadCF,
            aimCF,
            nil,
            {{ zid, true, math.random(1, 800), bulletIndex, 1 }},
            tool,
            {},
            {{ zid, {{{ false, "goldenLight" }}} }},
            nil, nil, nil
        )
    end)
    if not ok then warn("[ZoneDefense] shoot failed: "..tostring(err)) end
end

-- multi-target helper: hit EVERY zombie in range (true zone defense)
local function doAttackAll(maxRange)
    local hrp = myHRP()
    if not hrp then return 0 end
    local tool = getTool()
    if not tool or not shootEvent then return 0 end
    local n = 0
    for _, z in ipairs(getAllZombies()) do
        if Config.IgnoreExploder and z.Name == "exploderZombie" then continue end
        local part = getAimPart(z)
        local zid = z:GetAttribute("simZombieId")
        if part and zid then
            local d = (part.Position - hrp.Position).Magnitude
            local inZone = Config.ZoneCenter and (part.Position - Config.ZoneCenter).Magnitude <= Config.ZoneRadius
            if d <= maxRange or inZone then
                bulletIndex += 1
                local muzzle = getMuzzlePos(tool)
                pcall(function()
                    shootEvent:FireServer(
                        CFrame.new(),
                        CFrame.new(muzzle, part.Position),
                        nil,
                        {{ zid, true, math.random(1, 800), bulletIndex, 1 }},
                        tool, {},
                        {{ zid, {{{ false, "goldenLight" }}} }},
                        nil, nil, nil
                    )
                end)
                n += 1
                if n >= 20 then break end -- don't spam more than 20/ tick
            end
        end
    end
    return n
end

-- // KILL AURA LOOP (now uses shootBullet + simZombieId, hits all in zone) //
local lastAttack = 0
RunService.Heartbeat:Connect(function()
    if not Config.Enabled or not Config.KillAura then return end
    if os.clock() - lastAttack < Config.AttackDelay then return end
    local hrp = myHRP()
    if not hrp then return end
    lastAttack = os.clock()
    -- 1. Try multi-hit: everything in KillAuraRange OR inside zone
    local hits = 0
    pcall(function() hits = doAttackAll(Config.KillAuraRange) end)
    if hits > 0 then return end
    -- 2. Fallback single best target (also faces it)
    local target, part = getBestTarget(Config.KillAuraRange, false)
    if target and part then
        hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(part.Position.X, hrp.Position.Y, part.Position.Z))
        doAttack(target, part)
    end
end)

-- // AIMBOT LOOP (camera lock while holding AimKey) //
local aiming = false
game:GetService("UserInputService").InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Config.AimKey then aiming = true end
end)
game:GetService("UserInputService").InputEnded:Connect(function(inp)
    if inp.KeyCode == Config.AimKey then aiming = false end
end)
RunService.RenderStepped:Connect(function()
    if not Config.Aimbot or not aiming then return end
    local _, part = getBestTarget(5000, true)
    if part then
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, part.Position)
    end
end)

-- // HITBOX EXPANDER //
task.spawn(function()
    while true do
        task.wait(1)
        if Config.HitboxExpand then
            for _, z in ipairs(getAllZombies()) do
                local p = getAimPart(z)
                if p and p:IsA("BasePart") then
                    pcall(function()
                        p.CanCollide = false
                        p.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                        p.Transparency = math.min(p.Transparency, 0.5)
                    end)
                end
            end
        end
    end
end)

-- // ZONE DEFENSE - auto return to zone //
RunService.Heartbeat:Connect(function()
    if not Config.DefendZone or not Config.ZoneCenter then return end
    local hrp = myHRP()
    if not hrp then return end
    if (hrp.Position - Config.ZoneCenter).Magnitude > Config.ZoneRadius * 1.5 then
        -- walk back instead of teleport (less detectable). Change to CFrame teleport if you want:
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:MoveTo(Config.ZoneCenter) end
    end
end)

-- // ESP //
local espFolder = Instance.new("Folder")
espFolder.Name = "ZombieESP"
espFolder.Parent = game:GetService("CoreGui")

local function clearESP()
    for _, c in ipairs(espFolder:GetChildren()) do c:Destroy() end
end

task.spawn(function()
    while true do
        task.wait(0.25)
        clearESP()
        if not Config.ESP then continue end
        local hrp = myHRP()
        for _, z in ipairs(getAllZombies()) do
            local part = getAimPart(z)
            if part then
                local dist = hrp and math.floor((part.Position - hrp.Position).Magnitude) or 0
                if dist > Config.ESP_MaxDistance then continue end
                local hp, maxHp = getHealth(z)
                local label = z.Name .. " [" .. tostring(dist) .. "m]"
                if hp and maxHp then label = z.Name .. " " .. math.floor(hp) .. "/" .. math.floor(maxHp) .. " [" .. dist .. "m]" end

                local hl = Instance.new("Highlight")
                hl.Adornee = z
                hl.FillTransparency = 0.6
                hl.OutlineTransparency = 0
                if z.Name == "treasureZombie" then hl.FillColor = Color3.fromRGB(255,215,0)
                elseif z.Name == "exploderZombie" then hl.FillColor = Color3.fromRGB(255,0,0)
                elseif z.Name == "tankZombie" or z.Name == "bigBlackZombie" then hl.FillColor = Color3.fromRGB(170,0,255)
                else hl.FillColor = Color3.fromRGB(0,255,0) end
                hl.Parent = espFolder

                local bb = Instance.new("BillboardGui")
                bb.Adornee = part
                bb.Size = UDim2.new(0,200,0,30)
                bb.StudsOffset = Vector3.new(0,3,0)
                bb.AlwaysOnTop = true
                local tl = Instance.new("TextLabel")
                tl.Size = UDim2.new(1,0,1,0)
                tl.BackgroundTransparency = 1
                tl.Text = label
                tl.TextSize = 13
                tl.TextStrokeTransparency = 0
                tl.TextColor3 = Color3.new(1,1,1)
                tl.Parent = bb
                bb.Parent = espFolder
            end
        end
    end
end)

-- // SIMPLE GUI (no library needed, executor friendly) //
local function makeGUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "ZoneDefenseGUI"
    sg.ResetOnSpawn = false
    pcall(function() sg.Parent = game:GetService("CoreGui") end)
    if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 220, 0, 340)
    frame.Position = UDim2.new(0, 20, 0.5, -170)
    frame.BackgroundColor3 = Color3.fromRGB(20,20,25)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = sg
    local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0,8) corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,0,0,30)
    title.BackgroundTransparency = 1
    title.Text = "Zone Defense"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.Parent = frame

    local count = Instance.new("TextLabel")
    count.Size = UDim2.new(1,0,0,20)
    count.Position = UDim2.new(0,0,0,30)
    count.BackgroundTransparency = 1
    count.Text = "zombies: ..."
    count.TextColor3 = Color3.fromRGB(150,255,150)
    count.Font = Enum.Font.Gotham
    count.TextSize = 12
    count.Parent = frame
    task.spawn(function()
        while frame.Parent do
            task.wait(0.5)
            pcall(function()
                local n = #getAllZombies()
                local inZone = 0
                if Config.ZoneCenter then
                    for _, z in ipairs(getAllZombies()) do
                        local p = getAimPart(z)
                        if p and (p.Position-Config.ZoneCenter).Magnitude <= Config.ZoneRadius then inZone+=1 end
                        if inZone > 50 then break end
                    end
                end
                count.Text = string.format("zombies: %d | in zone: %d", n, inZone)
            end)
        end
    end)

    local y = 55
    local function toggle(name, get, set)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1,-20,0,26)
        b.Position = UDim2.new(0,10,0,y)
        b.BackgroundColor3 = Color3.fromRGB(35,35,45)
        b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.Gotham
        b.TextSize = 13
        b.Parent = frame
        local c = Instance.new("UICorner") c.CornerRadius=UDim.new(0,6) c.Parent=b
        local function refresh() b.Text = (get() and "[ON] " or "[OFF] ") .. name end
        b.MouseButton1Click:Connect(function() set(not get()) refresh() end)
        refresh()
        y += 30
        return b
    end

    toggle("Kill Aura", function() return Config.KillAura end, function(v) Config.KillAura=v end)
    toggle("Aimbot (hold C)", function() return Config.Aimbot end, function(v) Config.Aimbot=v end)
    toggle("ESP", function() return Config.ESP end, function(v) Config.ESP=v end)
    toggle("Hitbox Expand", function() return Config.HitboxExpand end, function(v) Config.HitboxExpand=v end)
    toggle("Defend Zone", function() return Config.DefendZone end, function(v)
        Config.DefendZone=v
        if v and myHRP() then Config.ZoneCenter = myHRP().Position end
    end)
    toggle("Ignore Exploder", function() return Config.IgnoreExploder end, function(v) Config.IgnoreExploder=v end)

    local zb = Instance.new("TextButton")
    zb.Size = UDim2.new(1,-20,0,26)
    zb.Position = UDim2.new(0,10,0,y)
    zb.BackgroundColor3 = Color3.fromRGB(60,60,180)
    zb.Text = "Set Zone Here"
    zb.TextColor3 = Color3.new(1,1,1)
    zb.Font = Enum.Font.GothamBold
    zb.TextSize = 13
    zb.Parent = frame
    local zc = Instance.new("UICorner") zc.CornerRadius=UDim.new(0,6) zc.Parent=zb
    zb.MouseButton1Click:Connect(function()
        if myHRP() then Config.ZoneCenter = myHRP().Position end
    end)
    y += 30

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1,-20,0,50)
    hint.Position = UDim2.new(0,10,0,y)
    hint.BackgroundTransparency = 1
    hint.Text = "Targets ONLY zombie Models.\nNever targets Players.\nAura range: "..Config.KillAuraRange
    hint.TextColor3 = Color3.fromRGB(180,180,180)
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextWrapped = true
    hint.Parent = frame
end
makeGUI()

-- Exports for console control:
-- getgenv().ZoneDefense = Config
getgenv().ZoneDefense = Config
getgenv().GetZombies = getAllZombies
getgenv().GetBestTarget = getBestTarget

print("[ZoneDefense] loaded. Zombies found: " .. #getAllZombies())
print("[ZoneDefense] Use getgenv().ZoneDefense.KillAura = true etc.")
