-- ZD v4 (rewrite): ESP + Teleport-Aim for autofire
-- Teleports 13 above zombie HRP, body pitched down at head, camera level/forward locked.

-- kill any old version (re-executing used to stack loops and fight itself)
pcall(function()
    if getgenv()._ZDcon then for _, c in ipairs(getgenv()._ZDcon) do pcall(function() c:Disconnect() end) end end
    pcall(function() game:GetService("RunService"):UnbindFromRenderStep("ZD_Cam") end)
    if workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    end
    local old = game:GetService("CoreGui"):FindFirstChild("ZD_GUI") if old then old:Destroy() end
    local old2 = game:GetService("CoreGui"):FindFirstChild("ZD_ESP") if old2 then old2:Destroy() end
end)
getgenv()._ZDcon = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Cfg = { Lock = false, ESP = true, Height = 13, Cycle = 0.6 }
getgenv().ZD = Cfg

local NAMES = { normalZombie=true, normalRedZombie=true, normalBlueZombie=true, crawlingZombie=true, speedZombie=true, blueMetalZombie=true, skeletonZombie=true, cyclopsZombie=true, bigCrawlingZombie=true, exploderZombie=true, armoredZombie=true, tankZombie=true, bigBlackZombie=true, treasureZombie=true, redSlateZombie=true, yellowSlateZombie=true, slimeZombie=true, halfSkeletonZombie=true, ghostZombie=true, spiderZombie=true }

local function HRP() local c = LocalPlayer.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function HUM() local c = LocalPlayer.Character return c and c:FindFirstChildOfClass("Humanoid") end

local function ok(m)
    if not m or not m:IsA("Model") then return false end
    if Players:GetPlayerFromCharacter(m) then return false end
    local p = m.Parent
    while p do if p.Name == "ObjectCache" then return false end p = p.Parent end
    local r = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("torso")
    if not r or not r:IsA("BasePart") then return false end
    local v = r.Position
    if math.abs(v.X) > 50000 then return false end
    local hp = m:GetAttribute("clientHealth")
    if hp ~= nil and hp <= 0 then return false end
    if m:GetAttribute("mainCrit") ~= nil then return true end
    if m:GetAttribute("simZombieId") ~= nil then return true end
    if NAMES[m.Name] then return true end
    return false
end
local function zhead(m) return m:FindFirstChild("head") or m:FindFirstChild("torso") end
local function zroot(m) return m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("torso") end

local cache, lastScan = {}, 0
local function scan()
    local out = {}
    local ai = Workspace:FindFirstChild("ai")
    local src = ai or Workspace
    for _, d in ipairs(src:GetDescendants()) do
        if d:IsA("Model") and ok(d) then
            table.insert(out, d)
            if #out >= 200 then break end
        end
    end
    -- if ai gave nothing, try full workspace once
    if #out == 0 and ai then
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("Model") and ok(d) then table.insert(out, d) if #out >= 200 then break end end
        end
    end
    cache, lastScan = out, os.clock()
    return out
end
task.spawn(function() while true do task.wait(0.5) pcall(scan) end end)
scan()
getgenv().ZD_get = function() return cache end

local dbg, cur, lookSm, idx, idxT = "idle", nil, nil, 1, 0

local function setAnchor(on)
    local h = HRP() if not h then return end
    pcall(function() h.Anchored = on end) -- anchored hover: gravity/knockback/controller can't drag us off
end

table.insert(getgenv()._ZDcon, RunService.Heartbeat:Connect(function()
    if not Cfg.Lock then
        if cur ~= nil then cur, lookSm, dbg = nil, nil, "off" setAnchor(false) Camera.CameraType = Enum.CameraType.Custom end
        return
    end
    local h = HRP() if not h then dbg = "no char" return end
    if os.clock() - lastScan > 0.6 then scan() end
    local list = cache
    if #list == 0 then dbg = "0 zombies (ai=" .. tostring(Workspace:FindFirstChild("ai") ~= nil) .. ")" setAnchor(false) return end
    -- closest-first order
    table.sort(list, function(a, b)
        local pa, pb = zroot(a), zroot(b)
        if not pa or not pb then return false end
        return (pa.Position - h.Position).Magnitude < (pb.Position - h.Position).Magnitude
    end)
    if os.clock() - idxT > Cfg.Cycle then idxT = os.clock() idx += 1 end
    if idx > #list then idx = 1 end
    local t = list[idx]
    if not t or not t.Parent then idx = 1 t = list[1] end
    if not t then return end
    cur = t
    local r, hd = zroot(t), zhead(t)
    if not r or not hd then return end
    -- lead moving targets
    local rv = (r.AssemblyLinearVelocity.Magnitude < 200 and not r.Anchored) and r.AssemblyLinearVelocity * 0.15 or Vector3.zero
    local hv = (hd.AssemblyLinearVelocity.Magnitude < 200 and not hd.Anchored) and hd.AssemblyLinearVelocity * 0.15 or Vector3.zero
    local rp, hp = r.Position + rv, hd.Position + hv
    local top = rp + Vector3.new(0, Cfg.Height, 0)
    local want = CFrame.new(top, hp)
    -- THE teleport: anchored PivotTo every frame (plain CFrame was silently reverted)
    local hum = HUM()
    if hum and hum.Seated then pcall(function() hum.Seated = false end) end
    setAnchor(true)
    pcall(function()
        LocalPlayer.Character:PivotTo(want)
        h.AssemblyLinearVelocity = Vector3.zero
        h.AssemblyAngularVelocity = Vector3.zero
    end)
    if not lookSm then lookSm = hp end
    lookSm = lookSm:Lerp(hp, 0.4)
    local got = HRP().Position
    local err = math.floor((got - top).Magnitude)
    dbg = ("z:%d [%d]=%s err:%d"):format(#list, idx, t.Name, err)
end))

-- camera LAST, glued to body, level look (bypass down-clamp), user input dead
RunService:BindToRenderStep("ZD_Cam", Enum.RenderPriority.Camera.Value + 1, function()
    if not Cfg.Lock or not cur or not lookSm then return end
    local h = HRP() if not h then return end
    pcall(function()
        if Camera.CameraType ~= Enum.CameraType.Scriptable then Camera.CameraType = Enum.CameraType.Scriptable end
        local cp = h.Position + Vector3.new(0, 3, 0)
        Camera.CFrame = CFrame.new(cp, Vector3.new(lookSm.X, cp.Y, lookSm.Z))
        Camera.Focus = CFrame.new(lookSm)
    end)
end)

-- ESP
local folder = Instance.new("Folder") folder.Name = "ZD_ESP" folder.Parent = game:GetService("CoreGui")
task.spawn(function()
    while true do
        task.wait(0.3)
        for _, c in ipairs(folder:GetChildren()) do c:Destroy() end
        if Cfg.ESP then
            for _, z in ipairs(cache) do
                local p = zhead(z)
                if p then
                    local txt = (z == cur and "[LOCK] " or "") .. z.Name
                    local hl = Instance.new("Highlight") hl.Adornee = z hl.FillTransparency = 0.65 hl.OutlineTransparency = 0
                    hl.FillColor = (z == cur) and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
                    hl.Parent = folder
                    local bb = Instance.new("BillboardGui") bb.Adornee = p bb.Size = UDim2.new(0, 200, 0, 20) bb.StudsOffset = Vector3.new(0, 3, 0) bb.AlwaysOnTop = true
                    local tl = Instance.new("TextLabel") tl.Size = UDim2.new(1, 0, 1, 0) tl.BackgroundTransparency = 1 tl.Text = txt tl.TextSize = 13 tl.TextStrokeTransparency = 0 tl.TextColor3 = Color3.new(1, 1, 1) tl.Parent = bb
                    bb.Parent = folder
                end
            end
        end
    end
end)

-- GUI
local sg = Instance.new("ScreenGui") sg.Name = "ZD_GUI" sg.ResetOnSpawn = false sg.Parent = game:GetService("CoreGui")
local f = Instance.new("Frame") f.Size = UDim2.new(0, 200, 0, 110) f.Position = UDim2.new(0, 20, 0.5, -55) f.BackgroundColor3 = Color3.fromRGB(20, 20, 25) f.BorderSizePixel = 0 f.Active = true f.Draggable = true f.Parent = sg
local u0 = Instance.new("UICorner") u0.CornerRadius = UDim.new(0, 8) u0.Parent = f
local function btn(y, key, label)
    local b = Instance.new("TextButton") b.Size = UDim2.new(1, -20, 0, 28) b.Position = UDim2.new(0, 10, 0, y) b.BackgroundColor3 = Color3.fromRGB(35, 35, 45) b.TextColor3 = Color3.new(1, 1, 1) b.Font = Enum.Font.Gotham b.TextSize = 13 b.Parent = f
    local u = Instance.new("UICorner") u.CornerRadius = UDim.new(0, 6) u.Parent = b
    local function ref() b.Text = ((Cfg[key] and "[ON] " or "[OFF] ") .. label) end
    b.MouseButton1Click:Connect(function() Cfg[key] = not Cfg[key] if not Cfg[key] then setAnchor(false) Camera.CameraType = Enum.CameraType.Custom end ref() end) ref()
end
btn(10, "Lock", "Teleport-Aim (13)") btn(42, "ESP", "ESP")
local lb = Instance.new("TextLabel") lb.Size = UDim2.new(1, -20, 0, 25) lb.Position = UDim2.new(0, 10, 0, 76) lb.BackgroundTransparency = 1 lb.Font = Enum.Font.Gotham lb.TextSize = 11 lb.TextColor3 = Color3.fromRGB(180, 180, 180) lb.TextWrapped = true lb.Parent = f
task.spawn(function() while f.Parent do task.wait(0.3) pcall(function() lb.Text = dbg end) end end)
print("[ZD v4] loaded")
