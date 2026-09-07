-- Zone Defense: ESP + Teleport-Aim only (for autofire guns)
-- Teleports above zombie HRP +7 and points camera at head. Autofire does the rest.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

getgenv().ZD = getgenv().ZD or { Lock = false, ESP = true, Height = 13, Range = 2000 }
if (getgenv().ZD.Height or 0) < 13 then getgenv().ZD.Height = 13 end
local Cfg = getgenv().ZD

local function hrp() local c = LocalPlayer.Character return c and c:FindFirstChild("HumanoidRootPart") end

local ZNAMES = { normalZombie=true, normalRedZombie=true, normalBlueZombie=true, crawlingZombie=true, speedZombie=true, blueMetalZombie=true, skeletonZombie=true, cyclopsZombie=true, bigCrawlingZombie=true, exploderZombie=true, armoredZombie=true, tankZombie=true, bigBlackZombie=true, treasureZombie=true, redSlateZombie=true, yellowSlateZombie=true, slimeZombie=true, halfSkeletonZombie=true, ghostZombie=true, spiderZombie=true }
local function isZombie(m)
    if not m or not m:IsA("Model") then return false end
    if Players:GetPlayerFromCharacter(m) then return false end
    local p = m.Parent
    while p do if p.Name == "ObjectCache" then return false end p = p.Parent end
    -- must have a position part (HRP or torso/head), not template far away
    local r = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("torso") or m:FindFirstChild("head")
    if not r or not r:IsA("BasePart") then return false end
    local v = r.Position
    if math.abs(v.X) > 100000 or math.abs(v.Y) > 100000 or math.abs(v.Z) > 100000 then return false end
    local hp = m:GetAttribute("clientHealth")
    if hp ~= nil and hp <= 0 then return false end
    -- accept if ANY of: custom attrs, zombie name, healthBar gui
    if m:GetAttribute("mainCrit") ~= nil or m:GetAttribute("mainTorsoName") ~= nil then return true end
    if m:GetAttribute("simZombieId") ~= nil then return true end
    if ZNAMES[m.Name] then return true end
    if m:FindFirstChild("healthBar", true) then return true end
    return false
end

local function head(m)
    return m:FindFirstChild(m:GetAttribute("mainCrit") or "head") or m:FindFirstChild("head") or m:FindFirstChild("torso")
end
local function root(m) return m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("torso") or head(m) end

getgenv().ZD_dbg = { scanned = 0, models = 0, ai = "?" }
-- cached scan: fast ai-folder path + slow workspace fallback, refreshed in background
-- (scanning Workspace:GetDescendants() every Heartbeat lagged the game -> showed 0)
local cache, cacheT = {}, 0
local function scanNow()
    local out, seen = {}, {}
    local scanned, models = 0, 0
    local ai = Workspace:FindFirstChild("ai")
    getgenv().ZD_dbg.ai = tostring(ai and ai:GetFullName() or "NO-AI")
    if ai then
        for _, d in ipairs(ai:GetDescendants()) do
            scanned += 1
            if d:IsA("Model") then models += 1
                if not seen[d] and isZombie(d) then seen[d] = true table.insert(out, d) if #out >= 300 then break end end
            end
        end
    end
    -- fallback: whole workspace, but only if ai gave nothing (live zombies elsewhere?)
    if #out == 0 then
        for _, d in ipairs(Workspace:GetDescendants()) do
            scanned += 1
            if d:IsA("Model") then models += 1
                if not seen[d] and isZombie(d) then seen[d] = true table.insert(out, d) if #out >= 300 then break end end
            end
        end
    end
    getgenv().ZD_dbg.scanned = scanned
    getgenv().ZD_dbg.models = models
    cache, cacheT = out, os.clock()
    return out
end
local function zombies()
    -- use cache if fresh (<0.5s), else rescan (also catches already-spawned)
    if os.clock() - cacheT < 0.5 and #cache >= 0 and cacheT > 0 then
        -- still validate cached ones are alive (cheap)
        local alive = {}
        for _, z in ipairs(cache) do
            if z.Parent and (z:GetAttribute("clientHealth") or 1) > 0 then table.insert(alive, z) end
        end
        if #alive > 0 then return alive end
    end
    return scanNow()
end
getgenv().ZD_get = zombies
getgenv().ZD_rescan = scanNow
task.spawn(function() while true do task.wait(0.5) pcall(scanNow) end end)
-- one-line scanner: prints where zombie-like models actually are
local function scanWhere()
    local counts = {}
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Model") and (d:GetAttribute("mainCrit") ~= nil or d:GetAttribute("simZombieId") ~= nil or d:FindFirstChild("healthBar", true)) then
            local k = (d.Parent and d.Parent:GetFullName() or "?") .. " | " .. d.Name
            counts[k] = (counts[k] or 0) + 1
        end
    end
    for k, v in pairs(counts) do print(v .. "x " .. k) end
    print("ai=" .. getgenv().ZD_dbg.ai .. " scanned=" .. getgenv().ZD_dbg.scanned .. " models=" .. getgenv().ZD_dbg.models)
end
getgenv().ZD_where = scanWhere

local dbg = ""
local cur = nil

-- main lock: cycle every zombie, teleport above with velocity prediction,
-- body pitched down at head, camera Scriptable-locked level/forward (no user jitter)
local cycleI, cycleT = 1, 0
local camLook = nil -- smoothed look target
local function setCamLock(on)
    pcall(function()
        if on then
            if Camera.CameraType ~= Enum.CameraType.Scriptable then Camera.CameraType = Enum.CameraType.Scriptable end
        else
            if Camera.CameraType == Enum.CameraType.Scriptable then Camera.CameraType = Enum.CameraType.Custom end
        end
    end)
end
local function predictPos(part)
    if not part or not part:IsA("BasePart") then return part and part.Position end
    local v = part.AssemblyLinearVelocity
    -- ignore crazy velocities / anchored
    if not v or v.Magnitude > 200 then return part.Position end
    if part.Anchored then return part.Position end
    return part.Position + v * 0.15 -- 150ms lead fixes moving-target lag
end
RunService.Heartbeat:Connect(function()
    if not Cfg.Lock then cur = nil camLook = nil setCamLock(false) return end
    local h = hrp() if not h then dbg = "no char" return end
    local list = zombies()
    if #list == 0 then dbg = "0 zombies" cur = nil setCamLock(false) return end
    setCamLock(true)
    table.sort(list, function(a, b)
        local pa, pb = root(a), root(b)
        if not pa or not pb then return false end
        return (pa.Position - h.Position).Magnitude < (pb.Position - h.Position).Magnitude
    end)
    if os.clock() - cycleT > 0.5 then cycleT = os.clock() cycleI += 1 end
    if cycleI > #list then cycleI = 1 end
    local target = list[cycleI]
    if not target or not target.Parent then cycleI = 1 target = list[1] end
    if not target then return end
    cur = target
    local r = root(target)
    local hd = head(target)
    if not r or not hd then return end
    -- predicted positions (fixes buggy offset on moving targets)
    local rPred = predictPos(r)
    local hPred = predictPos(hd)
    local topPos = rPred + Vector3.new(0, Cfg.Height, 0)
    -- smooth teleport: snap XZ, keep it stable even if target jitters
    pcall(function()
        h.AssemblyLinearVelocity = Vector3.zero
        h.AssemblyAngularVelocity = Vector3.zero
        h.CFrame = CFrame.new(topPos, hPred) -- body angled down at predicted head
    end)
    -- smooth the look target so camera doesn't snap every frame
    if not camLook then camLook = hPred end
    camLook = camLook:Lerp(hPred, 0.35)
    local d = math.floor((rPred - h.Position).Magnitude)
    dbg = ("z:%d -> %s d:%d"):format(#list, target.Name, d)
end)
-- camera applied LAST in RenderStepped at Camera priority+1: perfectly still, user can't fight it
RunService:BindToRenderStep("ZD_CamLock", Enum.RenderPriority.Camera.Value + 1, function()
    if not Cfg.Lock or not cur or not camLook then return end
    pcall(function()
        local cp = Camera.CFrame.Position
        -- level/forward look (same Y) = bypasses down-look clamp
        local want = CFrame.new(cp, Vector3.new(camLook.X, cp.Y, camLook.Z))
        -- hard lock: no lerp on camera itself, only on camLook above -> zero jitter
        Camera.CFrame = want
    end)
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
task.spawn(function() while f.Parent do task.wait(0.3) pcall(function() lb.Text = dbg .. "\n" .. getgenv().ZD_dbg.ai .. " m:" .. getgenv().ZD_dbg.models .. " h:" .. Cfg.Height end) end end)
print("[ZD] teleport-aim loaded")
