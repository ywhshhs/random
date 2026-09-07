-- ZD fresh (step 1): bare UI shell only, no features yet.

pcall(function()
    local o = game:GetService("CoreGui"):FindFirstChild("ZD_GUI") if o then o:Destroy() end
end)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Cfg = { ESP = false }
getgenv().ZD = Cfg

local sg = Instance.new("ScreenGui")
sg.Name = "ZD_GUI"
sg.ResetOnSpawn = false
sg.Parent = game:GetService("CoreGui")

local f = Instance.new("Frame")
f.Size = UDim2.new(0, 200, 0, 110)
f.Position = UDim2.new(0, 20, 0.5, -55)
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
local skyBtn = makeButton(68, "Sky Aimbot")

-- simple zombie check: Model with torso+head, not a player, not a template
local function isZombie(m)
    if not m or not m:IsA("Model") then return false end
    if Players:GetPlayerFromCharacter(m) then return false end
    local p = m.Parent
    while p do if p.Name == "ObjectCache" then return false end p = p.Parent end
    local torso = m:FindFirstChild("torso")
    local head = m:FindFirstChild("head")
    if not torso or not head then return false end
    if math.abs(torso.Position.X) > 50000 then return false end
    local hp = m:GetAttribute("clientHealth")
    if hp ~= nil and hp <= 0 then return false end
    return true
end

local zombies, lastScan = {}, 0
local function scan()
    local out = {}
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Model") and isZombie(d) then
            table.insert(out, d)
            if #out >= 200 then break end
        end
    end
    zombies, lastScan = out, os.clock()
end
task.spawn(function() while true do task.wait(1) pcall(scan) end end)
scan()
getgenv().ZD_get = function() return zombies end

local espFolder = Instance.new("Folder")
espFolder.Name = "ZD_ESP"
espFolder.Parent = game:GetService("CoreGui")

task.spawn(function()
    while true do
        task.wait(0.3)
        for _, c in ipairs(espFolder:GetChildren()) do c:Destroy() end
        if Cfg.ESP then
            if os.clock() - lastScan > 1 then scan() end
            for _, z in ipairs(zombies) do
                local head = z:FindFirstChild("head")
                if head then
                    local id = z:GetAttribute("simZombieId")
                    local hp, mx = z:GetAttribute("clientHealth"), z:GetAttribute("maxHealth")
                    local txt = z.Name .. " #" .. (id ~= nil and tostring(id) or "?")
                    if hp ~= nil and mx ~= nil then
                        txt = txt .. " " .. math.floor(hp) .. "/" .. math.floor(mx)
                    end
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

print("[ZD] ui shell loaded")
