-- Zone Defense: ESP + Teleport-Aim only (for autofire guns)
-- Teleports above zombie HRP +7 and points camera at head. Autofire does the rest.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

getgenv().ZD = getgenv().ZD or { Lock = false, ESP = true, Height = 7, Range = 2000 }
local Cfg = getgenv().ZD

local function hrp() local c = LocalPlayer.Character return c and c:FindFirstChild("HumanoidRootPart") end

local function isZombie(m)
    if not m or not m:IsA("Model") then return false end
    if Players:GetPlayerFromCharacter(m) then return false end
    if m:GetAttribute("mainCrit") == nil and m:GetAttribute("mainTorsoName") == nil then return false end
    local p = m.Parent
    while p do if p.Name == "ObjectCache" then return false end p = p.Parent end
    local r = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("torso")
    if r and r:IsA("BasePart") then
        local v = r.Position
        if math.abs(v.X) > 100000 or math.abs(v.Y) > 100000 or math.abs(v.Z) > 100000 then return false end
    else return false end
    local hp = m:GetAttribute("clientHealth")
    if hp ~= nil and hp <= 0 then return false end
    return true
end

local function head(m)
    return m:FindFirstChild(m:GetAttribute("mainCrit") or "head") or m:FindFirstChild("head") or m:FindFirstChild("torso")
end
local function root(m) return m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("torso") or head(m) end

local function zombies()
    local out, seen = {}, {}
    local ai = Workspace:FindFirstChild("ai")
    local src = ai or Workspace
    for _, d in ipairs(src:GetDescendants()) do
        if d:IsA("Model") and not seen[d] and isZombie(d) then seen[d] = true table.insert(out, d) if #out >= 300 then break end end
    end
    return out
end
getgenv().ZD_get = zombies

local dbg = ""
local cur = nil

-- main lock loop: closest zombie -> teleport above HRP -> camera look at head
RunService.Heartbeat:Connect(function()
    if not Cfg.Lock then cur = nil return end
    local h = hrp() if not h then dbg = "no char" return end
    local list = zombies()
    if #list == 0 then dbg = "0 zombies" cur = nil return end
    table.sort(list, function(a, b)
        local pa, pb = root(a), root(b)
        if not pa or not pb then return false end
        return (pa.Position - h.Position).Magnitude < (pb.Position - h.Position).Magnitude
    end)
    -- first one within range
    local target = nil
    for _, z in ipairs(list) do
        local r = root(z)
        if r and (r.Position - h.Position).Magnitude <= Cfg.Range then target = z break end
    end
    if not target then target = list[1] end
    cur = target
    local r = root(target)
    local hd = head(target)
    if not r or not hd then return end
    -- teleport above their HRP
    pcall(function()
        h.AssemblyLinearVelocity = Vector3.zero
        h.AssemblyAngularVelocity = Vector3.zero
        h.CFrame = CFrame.new(r.Position + Vector3.new(0, Cfg.Height, 0), hd.Position)
    end)
    -- point camera at head (cursor = center screen = head for autofire)
    pcall(function()
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, hd.Position)
    end)
    local d = math.floor((r.Position - h.Position).Magnitude)
    dbg = ("z:%d -> %s d:%d"):format(#list, target.Name, d)
end)

-- ESP
local folder = Instance.new("Folder") folder.Name = "ZD_ESP" folder.Parent = game:GetService("CoreGui")
task.spawn(function()
    while true do
        task.wait(0.3)
        for _, c in ipairs(folder:GetChildren()) do c:Destroy() end
        if Cfg.ESP then
            local h = hrp()
            for _, z in ipairs(zombies()) do
                local p = head(z)
                if p then
                    local hp, mx = z:GetAttribute("clientHealth"), z:GetAttribute("maxHealth")
                    local d = h and math.floor((p.Position - h.Position).Magnitude) or 0
                    local txt = z.Name .. " [" .. d .. "m]"
                    if hp and mx then txt = ("%s %d/%d [%dm]"):format(z.Name, hp, mx, d) end
                    if z == cur then txt = "[LOCK] " .. txt end
                    local hl = Instance.new("Highlight") hl.Adornee = z hl.FillTransparency = 0.65 hl.OutlineTransparency = 0
                    hl.FillColor = (z == cur) and Color3.fromRGB(255, 0, 0) or (z.Name == "treasureZombie" and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(0, 255, 0))
                    hl.Parent = folder
                    local bb = Instance.new("BillboardGui") bb.Adornee = p bb.Size = UDim2.new(0, 220, 0, 25) bb.StudsOffset = Vector3.new(0, 3, 0) bb.AlwaysOnTop = true
                    local tl = Instance.new("TextLabel") tl.Size = UDim2.new(1, 0, 1, 0) tl.BackgroundTransparency = 1 tl.Text = txt tl.TextSize = 13 tl.TextStrokeTransparency = 0 tl.TextColor3 = Color3.new(1, 1, 1) tl.Parent = bb
                    bb.Parent = folder
                end
            end
        end
    end
end)

-- GUI
local sg = Instance.new("ScreenGui") sg.Name = "ZD_GUI" sg.ResetOnSpawn = false
pcall(function() sg.Parent = game:GetService("CoreGui") end)
if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end
local f = Instance.new("Frame") f.Size = UDim2.new(0, 200, 0, 130) f.Position = UDim2.new(0, 20, 0.5, -65) f.BackgroundColor3 = Color3.fromRGB(20, 20, 25) f.BorderSizePixel = 0 f.Active = true f.Draggable = true f.Parent = sg
local cc0 = Instance.new("UICorner") cc0.CornerRadius = UDim.new(0, 8) cc0.Parent = f
local function btn(y, name, label)
    local b = Instance.new("TextButton") b.Size = UDim2.new(1, -20, 0, 28) b.Position = UDim2.new(0, 10, 0, y) b.BackgroundColor3 = Color3.fromRGB(35, 35, 45) b.TextColor3 = Color3.new(1, 1, 1) b.Font = Enum.Font.Gotham b.TextSize = 13 b.Parent = f
    local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0, 6) cc.Parent = b
    local function ref() b.Text = ((Cfg[name] and "[ON] " or "[OFF] ") .. label) end
    b.MouseButton1Click:Connect(function() Cfg[name] = not Cfg[name] ref() end) ref() return b
end
btn(10, "Lock", "Teleport-Aim") btn(42, "ESP", "ESP")
local lb = Instance.new("TextLabel") lb.Size = UDim2.new(1, -20, 0, 40) lb.Position = UDim2.new(0, 10, 0, 76) lb.BackgroundTransparency = 1 lb.TextWrapped = true lb.Font = Enum.Font.Gotham lb.TextSize = 11 lb.TextColor3 = Color3.fromRGB(180, 180, 180) lb.Parent = f
task.spawn(function() while f.Parent do task.wait(0.3) pcall(function() lb.Text = dbg .. "\nh:" .. Cfg.Height end) end end)
print("[ZD] teleport-aim loaded")
