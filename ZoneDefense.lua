-- Zone Defense: ESP + KillAura only (minimal)
-- Zombies are Models with attributes mainCrit/mainTorsoName/simZombieId, NO Humanoid. Never targets Players.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

getgenv().ZD = getgenv().ZD or { KillAura = false, ESP = false, Range = 2000, Delay = 0.15, ShowId = true }
if getgenv().ZD.Range < 1000 then getgenv().ZD.Range = 2000 end -- old 200 config was too short, force far
local Cfg = getgenv().ZD

-- remote
local shootEvent = ReplicatedStorage:WaitForChild("events", 5):WaitForChild("shootBullet", 5)
local status = "remote:" .. (shootEvent and "OK" or "MISSING")

-- bullet counter: server validates increasing index (log shows 6723+). Start high + sync to legit shots.
getgenv().ZD_bullet = getgenv().ZD_bullet or 8000
pcall(function()
    local old; old = hookmetamethod(game, "__namecall", function(self, ...)
        local m = getnamecallmethod()
        if m == "FireServer" and self == shootEvent then
            local a = {...}
            pcall(function()
                local t = a[4]
                if type(t) == "table" and t[1] and t[1][4] and type(t[1][4]) == "number" then
                    if t[1][4] >= getgenv().ZD_bullet then getgenv().ZD_bullet = t[1][4] + 1 end
                end
            end)
        end
        return old(self, ...)
    end)
end)

local function hrp() local c = LocalPlayer.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function tool()
    local c = LocalPlayer.Character
    if c then local t = c:FindFirstChildOfClass("Tool") if t then return t end end
    return nil -- Character ONLY: server ignores Backpack tools in most cases
end
local function ensureTool()
    local t = tool() if t then return t end
    -- auto-equip first backpack tool
    local b = LocalPlayer:FindFirstChild("Backpack")
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if b and hum then local bt = b:FindFirstChildOfClass("Tool") if bt then pcall(function() hum:EquipTool(bt) end) task.wait(0.2) return tool() end end
    return nil
end
-- one-shot test: fires 1 bullet at closest zombie, watches health. Returns string result.
local function testShot()
    local h = hrp() if not h then return "no char" end
    local t = ensureTool() if not t then return "equip a gun in hand first" end
    local list = zombies() if #list == 0 then return "0 zombies" end
    table.sort(list, function(a, b) local pa, pb = head(a), head(b) if not pa or not pb then return false end return (pa.Position - h.Position).Magnitude < (pb.Position - h.Position).Magnitude end)
    local z = list[1] local p = head(z) local id = z:GetAttribute("simZombieId")
    if not id then return z.Name .. " has NO simZombieId (cannot hit)" end
    local hp0 = z:GetAttribute("clientHealth")
    getgenv().ZD_bullet += 1 local idx = getgenv().ZD_bullet
    local muzzle = h.Position + Vector3.new(0, 1.5, 0)
    local a1 = CFrame.new(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    local a2 = CFrame.new(muzzle, p.Position)
    local ok, err = pcall(function()
        shootEvent:FireServer(a1, a2, nil, {{ id, true, math.random(1, 800), idx, 1 }}, t, {}, {{ id, {{{ false, "goldenLight" }}} }}, nil, nil, nil)
    end)
    if not ok then return "fire error: " .. tostring(err) end
    -- face target too (some games validate facing)
    pcall(function() h.CFrame = CFrame.new(h.Position, Vector3.new(p.Position.X, h.Position.Y, p.Position.Z)) end)
    pcall(function() t:Activate() end)
    task.wait(0.6)
    local hp1 = z:GetAttribute("clientHealth")
    return ("shot %s #%d idx=%d hp %s -> %s %s"):format(z.Name, id, idx, tostring(hp0), tostring(hp1), (hp1 and hp0 and hp1 < hp0) and "HIT!" or "NO DMG")
end
getgenv().ZD_test = testShot

local function isZombie(m)
    if not m or not m:IsA("Model") then return false end
    if Players:GetPlayerFromCharacter(m) then return false end
    if m:GetAttribute("mainCrit") == nil and m:GetAttribute("mainTorsoName") == nil then return false end
    -- skip templates in ObjectCache / far away storage (16M studs)
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

-- KILL AURA: fires shootBullet with simZombieId, like your log:
-- FireServer(identityCF, CFrame(muzzle, headPos), nil, {{id,true,rand,idx,1}}, tool, {}, {{id,{{{false,"goldenLight"}}}}}, nil,nil,nil)
local last = 0
local dbg = ""
RunService.Heartbeat:Connect(function()
    if not Cfg.KillAura then return end
    if os.clock() - last < Cfg.Delay then return end
    local h = hrp() if not h then dbg = "no char" return end
    local t = tool() if not t then t = ensureTool() if not t then dbg = "hold gun in hand!" return end end
    if not shootEvent then dbg = "no shootBullet" return end
    local list = zombies()
    if #list == 0 then dbg = "0 zombies" return end
    table.sort(list, function(a, b)
        local pa, pb = head(a), head(b)
        if not pa or not pb then return false end
        return (pa.Position - h.Position).Magnitude < (pb.Position - h.Position).Magnitude
    end)
    local fired, withId, noId, noHead, far = 0, 0, 0, 0, 0
    local nearest = math.huge
    for _, z in ipairs(list) do local p = head(z) if p then local d = (p.Position - h.Position).Magnitude if d < nearest then nearest = d end end end
    for _, z in ipairs(list) do
        if fired >= 3 then break end
        local p = head(z) if not p then noHead += 1 continue end
        local d = (p.Position - h.Position).Magnitude
        if d > Cfg.Range then far += 1 continue end
        local id = z:GetAttribute("simZombieId")
        if not id then noId += 1 continue end
        withId += 1
        getgenv().ZD_bullet += 1
        local idx = getgenv().ZD_bullet
        pcall(function()
            shootEvent:FireServer(CFrame.new(), CFrame.new(h.Position + Vector3.new(0, 1.5, 0), p.Position), nil, {{ id, true, math.random(1, 800), idx, 1 }}, t, {}, {{ id, {{{ false, "goldenLight" }}} }}, nil, nil, nil)
        end)
        fired += 1
    end
    local nearTxt = nearest == math.huge and "inf" or tostring(math.floor(nearest))
    dbg = ("z:%d fired:%d id:%d noid:%d near:%s far:%d nohead:%d idx:%d %s"):format(#list, fired, withId, noId, nearTxt, far, noHead, getgenv().ZD_bullet, t.Name)
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
                    local id = z:GetAttribute("simZombieId")
                    local d = h and math.floor((p.Position - h.Position).Magnitude) or 0
                    local txt = z.Name .. " [" .. d .. "m]"
                    if hp and mx then txt = ("%s %d/%d [%dm]"):format(z.Name, hp, mx, d) end
                    if Cfg.ShowId then txt ..= (id and (" #" .. id) or " #NOID") end
                    local hl = Instance.new("Highlight") hl.Adornee = z hl.FillTransparency = 0.65 hl.OutlineTransparency = 0
                    hl.FillColor = z.Name == "treasureZombie" and Color3.fromRGB(255, 215, 0) or (z.Name == "exploderZombie" and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0))
                    hl.Parent = folder
                    local bb = Instance.new("BillboardGui") bb.Adornee = p bb.Size = UDim2.new(0, 220, 0, 25) bb.StudsOffset = Vector3.new(0, 3, 0) bb.AlwaysOnTop = true
                    local tl = Instance.new("TextLabel") tl.Size = UDim2.new(1, 0, 1, 0) tl.BackgroundTransparency = 1 tl.Text = txt tl.TextSize = 13 tl.TextStrokeTransparency = 0 tl.TextColor3 = Color3.new(1, 1, 1) tl.Parent = bb
                    bb.Parent = folder
                end
            end
        end
    end
end)

-- tiny GUI
local sg = Instance.new("ScreenGui") sg.Name = "ZD_GUI" sg.ResetOnSpawn = false
pcall(function() sg.Parent = game:GetService("CoreGui") end)
if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end
local f = Instance.new("Frame") f.Size = UDim2.new(0, 200, 0, 185) f.Position = UDim2.new(0, 20, 0.5, -90) f.BackgroundColor3 = Color3.fromRGB(20, 20, 25) f.BorderSizePixel = 0 f.Active = true f.Draggable = true f.Parent = sg
local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = f
local function btn(y, name, fn)
    local b = Instance.new("TextButton") b.Size = UDim2.new(1, -20, 0, 28) b.Position = UDim2.new(0, 10, 0, y) b.BackgroundColor3 = Color3.fromRGB(35, 35, 45) b.TextColor3 = Color3.new(1, 1, 1) b.Font = Enum.Font.Gotham b.TextSize = 13 b.Parent = f
    local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0, 6) cc.Parent = b
    local function ref() b.Text = ((Cfg[name] and "[ON] " or "[OFF] ") .. fn) end
    b.MouseButton1Click:Connect(function() Cfg[name] = not Cfg[name] ref() end) ref() return b
end
btn(10, "KillAura", "Kill Aura") btn(42, "ESP", "ESP")
local tb = Instance.new("TextButton") tb.Size = UDim2.new(1, -20, 0, 28) tb.Position = UDim2.new(0, 10, 0, 74) tb.BackgroundColor3 = Color3.fromRGB(60, 60, 180) tb.Text = "TEST 1 SHOT" tb.TextColor3 = Color3.new(1, 1, 1) tb.Font = Enum.Font.GothamBold tb.TextSize = 13 tb.Parent = f
local tbc = Instance.new("UICorner") tbc.CornerRadius = UDim.new(0, 6) tbc.Parent = tb
tb.MouseButton1Click:Connect(function() task.spawn(function() local r = testShot() lb.Text = r print("[ZD test] " .. r) end) end)
local lb = Instance.new("TextLabel") lb.Size = UDim2.new(1, -20, 0, 60) lb.Position = UDim2.new(0, 10, 0, 108) lb.BackgroundTransparency = 1 lb.TextWrapped = true lb.Font = Enum.Font.Gotham lb.TextSize = 11 lb.TextColor3 = Color3.fromRGB(180, 180, 180) lb.Parent = f
task.spawn(function() while f.Parent do task.wait(0.3) pcall(function() if lb.Text:sub(1, 4) ~= "shot" then lb.Text = status .. "\n" .. dbg .. "\nrange:" .. Cfg.Range end end) end end)
print("[ZD] loaded. " .. status)
