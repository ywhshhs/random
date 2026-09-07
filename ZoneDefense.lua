-- ZD fresh (step 1): bare UI shell only, no features yet.

pcall(function()
    local o = game:GetService("CoreGui"):FindFirstChild("ZD_GUI") if o then o:Destroy() end
    local o2 = game:GetService("CoreGui"):FindFirstChild("ZD_ESP") if o2 then o2:Destroy() end
    game:GetService("RunService"):UnbindFromRenderStep("ZD_Cam")
    if workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    end
end)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Cfg = { ESP = false, Sky = false, SkyH = 20 }
getgenv().ZD = Cfg

local RunService = game:GetService("RunService")

local function HRP() local c = LocalPlayer.Character return c and c:FindFirstChild("HumanoidRootPart") end

-- aim part: head first, then any solid part (covers non-standard variants)
local function aimPart(m)
    local p = m:FindFirstChild("head") or m:FindFirstChild("torso") or m:FindFirstChild("HumanoidRootPart")
    if p and p:IsA("BasePart") then return p end
    for _, c in ipairs(m:GetChildren()) do
        if c:IsA("BasePart") then return c end
    end
    return nil
end

-- wall check: clear line from our eye to a target part
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function canSee(fromPos, targetModel, targetPart)
    if not targetPart then return false end
    local excl = {}
    local c = LocalPlayer.Character
    if c then table.insert(excl, c) end
    table.insert(excl, targetModel)
    rayParams.FilterDescendantsInstances = excl
    local dir = targetPart.Position - fromPos
    local res = Workspace:Raycast(fromPos, dir, rayParams)
    -- visible = nothing solid in the way
    return res == nil
end

-- shared zombie state (declared up here so every loop below sees the SAME local)
local ZNAMES = { normalZombie=true, normalRedZombie=true, normalBlueZombie=true, crawlingZombie=true, speedZombie=true, blueMetalZombie=true, skeletonZombie=true, cyclopsZombie=true, bigCrawlingZombie=true, exploderZombie=true, armoredZombie=true, tankZombie=true, bigBlackZombie=true, treasureZombie=true, redSlateZombie=true, yellowSlateZombie=true, slimeZombie=true, halfSkeletonZombie=true, ghostZombie=true, spiderZombie=true }
-- NOTE: live zombies ALSO live under ObjectCache folders (ai has 7+ of them),
-- so we must NOT ban the folder. Templates are filtered by far-away position instead.
local function isZombie(m)
    if not m or not m:IsA("Model") then return false end
    if Players:GetPlayerFromCharacter(m) then return false end
    -- any position part counts (some variants like spider lack torso/head)
    local rp = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("torso") or m:FindFirstChild("head")
    if not rp then
        for _, c in ipairs(m:GetChildren()) do
            if c:IsA("BasePart") then rp = c break end
        end
    end
    if not rp then return false end
    -- templates are parked ~16M studs out; live ones are near the map
    if math.abs(rp.Position.X) > 50000 or math.abs(rp.Position.Y) > 50000 then return false end
    local hp = m:GetAttribute("clientHealth")
    if hp ~= nil and hp <= 0 then return false end
    -- every zombie enemy name ends with "Zombie" (boss is the exception, caught below)
    if m.Name:sub(-6) == "Zombie" then return true end
    if m:GetAttribute("mainCrit") ~= nil or m:GetAttribute("simZombieId") ~= nil then return true end
    if ZNAMES[m.Name] then return true end
    if m:FindFirstChild("healthBar", true) then return true end
    return false
end

local zombies, lastScan = {}, 0
local function scan()
    local out = {}
    local ai = Workspace:FindFirstChild("ai")
    local src = ai or Workspace
    for _, d in ipairs(src:GetDescendants()) do
        if d:IsA("Model") and isZombie(d) then
            table.insert(out, d)
            if #out >= 200 then break end
        end
    end
    zombies, lastScan = out, os.clock()
end
getgenv().ZD_list = function()
    local counts = {}
    for _, z in ipairs(typeof(zombies) == "table" and zombies or {}) do
        counts[z.Name] = (counts[z.Name] or 0) + 1
    end
    for n, c in pairs(counts) do print(c .. "x " .. n) end
    print("total: " .. #zombies)
end
task.spawn(function() while true do task.wait(1) pcall(scan) end end)
scan()
getgenv().ZD_get = function() return zombies end

local sg = Instance.new("ScreenGui")
sg.Name = "ZD_GUI"
sg.ResetOnSpawn = false
sg.Parent = game:GetService("CoreGui")

local countLb = nil
local f = Instance.new("Frame")
f.Size = UDim2.new(0, 200, 0, 130)
f.Position = UDim2.new(0, 20, 0.5, -65)
f.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
f.Parent = sg

local u0 = Instance.new("UICorner")
u0.CornerRadius = UDim.new(0, 8)
u0.Parent = f

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundTransparency = 1
title.Text = "Zone Defense"
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextColor3 = Color3.new(1, 1, 1)
title.Parent = f

local function makeButton(y, text)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 28)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.Gotham
    b.TextSize = 13
    b.Parent = f
    local u = Instance.new("UICorner")
    u.CornerRadius = UDim.new(0, 6)
    u.Parent = b
    return b
end

local espBtn = makeButton(36, "[OFF] ESP")
local skyBtn = makeButton(68, "[OFF] Sky Aimbot")

-- sky lift only: +20 up, anchored hover. No aiming yet.
local savedGround, skyPos, aimTarget, lookSm = nil, nil, nil, nil
skyBtn.MouseButton1Click:Connect(function()
    Cfg.Sky = not Cfg.Sky
    skyBtn.Text = (Cfg.Sky and "[ON] " or "[OFF] ") .. "Sky Aimbot"
    local h = HRP()
    if Cfg.Sky then
        if h then
            savedGround = h.Position
            skyPos = savedGround + Vector3.new(0, Cfg.SkyH, 0)
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Seated then hum.Seated = false end
            h.Anchored = true
            LocalPlayer.Character:PivotTo(CFrame.new(skyPos))
            h.AssemblyLinearVelocity = Vector3.zero
        end
    else
        if h then
            h.Anchored = false
            if savedGround then
                LocalPlayer.Character:PivotTo(CFrame.new(savedGround + Vector3.new(0, 3, 0)))
            end
            h.AssemblyLinearVelocity = Vector3.zero
        end
        savedGround, skyPos, aimTarget, lookSm = nil, nil, nil, nil
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    end
end)

-- hold the hover (re-pin if knocked off) + pick closest target while up
RunService.Heartbeat:Connect(function()
    if not Cfg.Sky or not skyPos then aimTarget, lookSm = nil, nil return end
    local h = HRP() if not h then return end
    if (h.Position - skyPos).Magnitude > 3 then
        h.Anchored = true
        LocalPlayer.Character:PivotTo(CFrame.new(skyPos))
        h.AssemblyLinearVelocity = Vector3.zero
    end
    -- closest VISIBLE zombie to us
    local best, bd = nil, math.huge
    local eye = h.Position + Vector3.new(0, 3, 0)
    for _, z in ipairs(typeof(zombies) == "table" and zombies or {}) do
        local hd = aimPart(z)
        if hd then
            local d = (hd.Position - h.Position).Magnitude
            if d < bd and canSee(eye, z, hd) then best, bd = z, d end
        end
    end
    if best ~= aimTarget then
        aimTarget = best -- new target: snap instantly, no laggy glide-over
        lookSm = nil
    end
    local bp = best and aimPart(best) or nil
    local hp = bp and bp.Position or nil
    if hp then
        if not lookSm then lookSm = hp end
        lookSm = lookSm:Lerp(hp, 0.65) -- fast smoothing: tracks movers, no jitter
    else
        lookSm = nil
    end
end)

-- camera: full free pitch (no axis locked), applied last so the game can't fight it.
-- Scriptable only stops YOUR mouse fighting the script, not the pitch range.
RunService:BindToRenderStep("ZD_Cam", Enum.RenderPriority.Camera.Value + 1, function()
    if not Cfg.Sky or not aimTarget or not lookSm then return end
    local h = HRP() if not h then return end
    local cam = workspace.CurrentCamera
    pcall(function()
        if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
        local eye = h.Position + Vector3.new(0, 3, 0)
        cam.CFrame = CFrame.new(eye, lookSm) -- true 3D aim, Y free
        cam.Focus = CFrame.new(lookSm)
    end)
end)

local espFolder = Instance.new("Folder")
espFolder.Name = "ZD_ESP"
espFolder.Parent = game:GetService("CoreGui")

task.spawn(function()
    while true do
        task.wait(0.3)
        for _, c in ipairs(espFolder:GetChildren()) do c:Destroy() end
        if Cfg.ESP then
            if os.clock() - lastScan > 1 then scan() end
            for _, z in ipairs(typeof(zombies) == "table" and zombies or {}) do
                local head = aimPart(z)
                if head then
                    local id = z:GetAttribute("simZombieId")
                    local hp, mx = z:GetAttribute("clientHealth"), z:GetAttribute("maxHealth")
                    local txt = z.Name .. " #" .. (id ~= nil and tostring(id) or "?")
                    if hp ~= nil and mx ~= nil then
                        txt = txt .. " " .. math.floor(hp) .. "/" .. math.floor(mx)
                    else
                        txt = txt .. " (no hp)"
                    end
                    txt = txt .. " [" .. head.Name .. "]"
                    local bb = Instance.new("BillboardGui")
                    bb.Adornee = head
                    bb.Size = UDim2.new(0, 220, 0, 25)
                    bb.StudsOffset = Vector3.new(0, 3, 0)
                    bb.AlwaysOnTop = true
                    local tl = Instance.new("TextLabel")
                    tl.Size = UDim2.new(1, 0, 1, 0)
                    tl.BackgroundTransparency = 1
                    tl.Text = txt
                    tl.TextSize = 13
                    tl.TextStrokeTransparency = 0
                    tl.TextColor3 = Color3.new(1, 1, 1)
                    tl.Parent = bb
                    bb.Parent = espFolder
                end
            end
        end
    end
end)

espBtn.MouseButton1Click:Connect(function()
    Cfg.ESP = not Cfg.ESP
    espBtn.Text = (Cfg.ESP and "[ON] " or "[OFF] ") .. "ESP"
end)

countLb = Instance.new("TextLabel")
countLb.Size = UDim2.new(1, -20, 0, 18)
countLb.Position = UDim2.new(0, 10, 0, 100)
countLb.BackgroundTransparency = 1
countLb.Text = "zombies: 0"
countLb.Font = Enum.Font.Gotham
countLb.TextSize = 11
countLb.TextColor3 = Color3.fromRGB(150, 255, 150)
countLb.Parent = f
task.spawn(function()
    while f.Parent do
        task.wait(0.5)
        pcall(function()
            countLb.Text = "zombies: " .. #zombies
        end)
    end
end)

print("[ZD] ui shell loaded")
