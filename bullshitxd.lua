-- bullshitxd main (step 1): 4 tabs + barebones aimbot (lock only, no checks).
-- Bump UI_URL when bullshitxd_ui.lua changes upstream (mobile-fixed sample UI).
local UI_URL = "https://raw.githubusercontent.com/ywhshhs/random/ad67aa227bf55a11c6bd9b2aab8674519cba35e1/bullshitxd_ui.lua"

if getgenv().bsxd then
    pcall(function() getgenv().bsxd.unload() end)
end

local library = loadstring(game:HttpGet(UI_URL))()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- anti-void on launch (universal): NaN kill-height so falling never kills.
-- Re-applied if the game resets it. pcall-guarded, no toggle (keeps LOC small).
pcall(function()
    Workspace.FallenPartsDestroyHeight = 0 / 0
end)
pcall(function()
    Workspace:GetPropertyChangedSignal("FallenPartsDestroyHeight"):Connect(function()
        pcall(function() Workspace.FallenPartsDestroyHeight = 0 / 0 end)
    end)
end)

local S = { aimbot = false, autoSelect = true, teamCheck = false, wallCheck = false, prediction = 0, smoothing = 0, targetPart = "Head",
    fov = false, fovSize = 120, fovColor = Color3.fromRGB(255, 255, 255), fovRainbow = false, fovFilled = false, fovFillColor = Color3.fromRGB(255, 255, 255), fovFillRainbow = false, rainbowSpeed = 1, fovMode = "Center",
    tracers = false, tracerOrigin = "Cursor", tracerColor = Color3.fromRGB(255, 255, 255), tracerRainbow = false, tracerThickness = 2,
    deadzone = 0, humanize = false, humanizeStrength = 2, streamproof = false,
    aliveCheck = true, lockedColor = Color3.fromRGB(255, 150, 150) }

-- R6 / R15 part lists. Dropdown swaps based on LOCAL rig; resolver below
-- handles targets on the opposite rig via aliases.
local PART_LISTS = {
    R6 = { "Head", "Torso", "HumanoidRootPart", "Left Arm", "Right Arm", "Left Leg", "Right Leg" },
    R15 = { "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" },
}
local PART_ALIASES = {
    ["Head"] = { "Head" },
    ["HumanoidRootPart"] = { "HumanoidRootPart" },
    ["Torso"] = { "Torso", "UpperTorso", "LowerTorso" },
    ["UpperTorso"] = { "UpperTorso", "Torso" },
    ["LowerTorso"] = { "LowerTorso", "Torso" },
    ["Left Arm"] = { "Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand" },
    ["Right Arm"] = { "Right Arm", "RightUpperArm", "RightLowerArm", "RightHand" },
    ["Left Leg"] = { "Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" },
    ["Right Leg"] = { "Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot" },
    ["LeftUpperArm"] = { "LeftUpperArm", "Left Arm" },
    ["LeftLowerArm"] = { "LeftLowerArm", "Left Arm" },
    ["LeftHand"] = { "LeftHand", "Left Arm" },
    ["RightUpperArm"] = { "RightUpperArm", "Right Arm" },
    ["RightLowerArm"] = { "RightLowerArm", "Right Arm" },
    ["RightHand"] = { "RightHand", "Right Arm" },
    ["LeftUpperLeg"] = { "LeftUpperLeg", "Left Leg" },
    ["LeftLowerLeg"] = { "LeftLowerLeg", "Left Leg" },
    ["LeftFoot"] = { "LeftFoot", "Left Leg" },
    ["RightUpperLeg"] = { "RightUpperLeg", "Right Leg" },
    ["RightLowerLeg"] = { "RightLowerLeg", "Right Leg" },
    ["RightFoot"] = { "RightFoot", "Right Leg" },
}

local function getLocalRig()
    local ok, rig = pcall(function()
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h and h.RigType == Enum.HumanoidRigType.R6 then return "R6" end
        return "R15"
    end)
    return (ok and rig) or "R15"
end

local function resolvePart(char, wanted)
    if not char then return nil end
    local aliases = PART_ALIASES[wanted] or PART_ALIASES["Head"]
    for _, name in ipairs(aliases) do
        local p = char:FindFirstChild(name)
        if p and p:IsA("BasePart") then return p end
    end
    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head end
    return nil
end
local UIS = game:GetService("UserInputService")

-- perf locals (no per-frame allocs, no lag spikes)
local V2 = Vector2.new
local HSV = Color3.fromHSV
local WHITE = Color3.fromRGB(255, 255, 255)
local EXP, SIN, COS, SQRT = math.exp, math.sin, math.cos, math.sqrt

-- FOV anchor: screen center (mobile-friendly) or live cursor
local function getFovAnchor(vp)
    if S.fovMode == "Cursor" then
        local ok, mp = pcall(function() return UIS:GetMouseLocation() end)
        if ok and mp then return V2(mp.X, mp.Y) end
    end
    return V2(vp.X * 0.5, vp.Y * 0.5)
end

-- drawings BEFORE ui (callbacks fire at build, visuals must exist)
local fovCircle
pcall(function()
    local ok, obj = pcall(function() return Drawing.new("Circle") end)
    if ok and obj and type(obj) ~= "string" then fovCircle = obj end
end)
if not fovCircle then fovCircle = setmetatable({}, { __index = function() return nil end, __newindex = function() end }) end
pcall(function()
    fovCircle.Visible = false
    fovCircle.Thickness = 2
    fovCircle.Color = Color3.fromRGB(255, 255, 255)
    fovCircle.Transparency = 1
    fovCircle.Filled = false
    fovCircle.Radius = 120
    fovCircle.Position = Vector2.new(500, 500)
end)
local tracerLine
pcall(function()
    local ok, obj = pcall(function() return Drawing.new("Line") end)
    if ok and obj and type(obj) ~= "string" then tracerLine = obj end
end)
if not tracerLine then tracerLine = setmetatable({}, { __index = function() return nil end, __newindex = function() end }) end
pcall(function()
    tracerLine.Visible = false
    tracerLine.Thickness = 2
    tracerLine.Color = Color3.fromRGB(255, 255, 255)
    tracerLine.Transparency = 1
end)
-- FOV outline (Da Hood / AirHub pattern): black ring behind main circle
local fovOutline
pcall(function()
    local ok, obj = pcall(function() return Drawing.new("Circle") end)
    if ok and obj and type(obj) ~= "string" then fovOutline = obj end
end)
if not fovOutline then fovOutline = setmetatable({}, { __index = function() return nil end, __newindex = function() end }) end
pcall(function()
    fovOutline.Visible = false
    fovOutline.Thickness = 3
    fovOutline.Color = Color3.fromRGB(0, 0, 0)
    fovOutline.Transparency = 1
    fovOutline.Filled = false
    fovOutline.Radius = 120
    fovOutline.Position = Vector2.new(500, 500)
end)
local currentAimPart = nil -- set by aim loop, read by visual loop

getgenv().bsxd = {
    state = S,
    unload = function()
        S.aimbot = false
        pcall(function() RunService:UnbindFromRenderStep("bsxd_aim") end)
        pcall(function() RunService:UnbindFromRenderStep("bsxd_vis") end)
        pcall(function() fovCircle.Visible = false end)
        pcall(function() fovOutline.Visible = false end)
        pcall(function() tracerLine.Visible = false end)
        pcall(function() fovCircle.Remove(fovCircle) end)
        pcall(function() fovOutline.Remove(fovOutline) end)
        pcall(function() tracerLine.Remove(tracerLine) end)
        pcall(function() library:unload() end)
    end,
}

local window = library:window({ name = "bullshitxd" })
local mainTab = window:tab({ name = "Main" })
local moveTab = window:tab({ name = "Movement" })
local visTab = window:tab({ name = "Visuals" })
local setTab = window:tab({ name = "Settings" })

-- empty placeholders (wired later)
moveTab:section({ name = "Placeholder", side = "left" })
visTab:section({ name = "Placeholder", side = "left" })
setTab:section({ name = "Placeholder", side = "left" })

-- barebones+ aimbot: closest head + team/wall/prediction/smoothing.
local aimSec = mainTab:section({ name = "Aimbot", side = "left" })
aimSec:toggle({
    name = "Enabled",
    flag = "aimbot_enabled",
    default = false,
    callback = function(v) S.aimbot = v end,
})
aimSec:toggle({
    name = "Auto Select",
    flag = "aimbot_autoselect",
    default = true,
    callback = function(v) S.autoSelect = v end,
})
aimSec:toggle({
    name = "Alive Check",
    flag = "aimbot_alivecheck",
    default = true,
    callback = function(v) S.aliveCheck = v end,
})
aimSec:toggle({
    name = "Team Check",
    flag = "aimbot_teamcheck",
    default = false,
    callback = function(v) S.teamCheck = v end,
})
aimSec:toggle({
    name = "Wall Check",
    flag = "aimbot_wallcheck",
    default = false,
    callback = function(v) S.wallCheck = v end,
})
aimSec:slider({
    name = "Prediction",
    suffix = " st",
    flag = "aimbot_prediction",
    min = 0,
    max = 10,
    interval = 0.01,
    default = 0,
    callback = function(v) S.prediction = v end,
})
aimSec:slider({
    name = "Smoothing",
    suffix = "",
    flag = "aimbot_smoothing",
    min = 0,
    max = 5,
    interval = 0.01,
    default = 0,
    callback = function(v) S.smoothing = v end,
})
aimSec:slider({
    name = "Deadzone",
    suffix = " px",
    flag = "aimbot_deadzone",
    min = 0,
    max = 60,
    interval = 1,
    default = 0,
    callback = function(v) S.deadzone = v end,
})
aimSec:toggle({
    name = "Humanize",
    flag = "aimbot_humanize",
    default = false,
    callback = function(v) S.humanize = v end,
})
aimSec:slider({
    name = "Humanize Strength",
    suffix = "",
    flag = "aimbot_humanize_str",
    min = 0,
    max = 10,
    interval = 0.5,
    default = 2,
    callback = function(v) S.humanizeStrength = v end,
})
local targetDropdown = aimSec:dropdown({
    name = "Target Part",
    flag = "aimbot_targetpart",
    items = PART_LISTS[getLocalRig()],
    default = "Head",
    callback = function(v)
        -- dropdown deselects to nil on re-click: fall back to Head
        S.targetPart = (type(v) == "string" and v) or "Head"
    end,
})
-- swap R6 <-> R15 options when the user respawns into a different rig
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    local rig = getLocalRig()
    pcall(function() targetDropdown:list(PART_LISTS[rig]) end)
    local cur = S.targetPart
    local valid = false
    for _, n in ipairs(PART_LISTS[rig]) do if n == cur then valid = true break end end
    if not valid then
        S.targetPart = "Head"
        pcall(function() targetDropdown:set("Head") end)
    end
end)

-- aimbot visuals: FOV + tracers, still inside Main tab (no extra tab)
local fovSec = mainTab:section({ name = "Field of View", side = "right" })
fovSec:toggle({ name = "FOV Enabled", flag = "fov_enabled", default = false, callback = function(v) S.fov = v end })
fovSec:slider({ name = "FOV Size", suffix = " px", flag = "fov_size", min = 10, max = 500, interval = 1, default = 120, callback = function(v) S.fovSize = v end })
fovSec:toggle({ name = "FOV Rainbow", flag = "fov_rainbow", default = false, callback = function(v) S.fovRainbow = v end })
fovSec:toggle({ name = "FOV Filled", flag = "fov_filled", default = false, callback = function(v) S.fovFilled = v end })
fovSec:toggle({ name = "FOV Fill Rainbow", flag = "fov_fillrainbow", default = false, callback = function(v) S.fovFillRainbow = v end })
fovSec:slider({ name = "Rainbow Speed", suffix = "x", flag = "fov_rainbowspeed", min = 0.1, max = 5, interval = 0.1, default = 1, callback = function(v) S.rainbowSpeed = v end })
local _fovColor = fovSec:colorpicker({ name = "FOV Color", flag = "fov_color", color = Color3.fromRGB(255, 255, 255), callback = function(c) S.fovColor = c end })
local _fovFill = fovSec:colorpicker({ name = "FOV Fill Color", flag = "fov_fillcolor", color = Color3.fromRGB(255, 255, 255), callback = function(c) S.fovFillColor = c end })
local fovModeDD = fovSec:dropdown({ name = "FOV Position", flag = "fov_mode", items = { "Center", "Cursor" }, default = "Center", callback = function(v) S.fovMode = (type(v) == "string" and v) or "Center" end })
fovSec:toggle({ name = "Streamproof (hide all visuals)", flag = "fov_streamproof", default = false, callback = function(v) S.streamproof = v end })

local tracerSec = mainTab:section({ name = "Tracers", side = "right" })
tracerSec:toggle({ name = "Tracers Enabled", flag = "tracer_enabled", default = false, callback = function(v) S.tracers = v end })
local tracerOriginDD = tracerSec:dropdown({ name = "Tracer Origin", flag = "tracer_origin", items = { "Cursor", "Top", "Bottom" }, default = "Cursor", callback = function(v) S.tracerOrigin = (type(v) == "string" and v) or "Cursor" end })
tracerSec:toggle({ name = "Tracer Rainbow", flag = "tracer_rainbow", default = false, callback = function(v) S.tracerRainbow = v end })
tracerSec:slider({ name = "Tracer Thickness", suffix = " px", flag = "tracer_thickness", min = 1, max = 6, interval = 1, default = 2, callback = function(v) S.tracerThickness = v end })
local _tracerColor = tracerSec:colorpicker({ name = "Tracer Color", flag = "tracer_color", color = Color3.fromRGB(255, 255, 255), callback = function(c) S.tracerColor = c end })
local _lockedColor = fovSec:colorpicker({ name = "Locked Color", flag = "fov_lockedcolor", color = Color3.fromRGB(255, 150, 150), callback = function(c) S.lockedColor = c end })

local function predictPos(part, char, hum)
    local P = S.prediction or 0
    if P <= 0 then return part.Position end
    -- P is studs (0.01 precision). MoveDirection primary, velocity fallback. No pcall (hot path).
    local md = hum and hum.MoveDirection
    if md and (md.X ~= 0 or md.Y ~= 0 or md.Z ~= 0) then
        local pp = part.Position
        return Vector3.new(pp.X + md.X * P, pp.Y + md.Y * P, pp.Z + md.Z * P)
    end
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local vel = hrp and hrp.Velocity
    if vel and vel.Magnitude > 0.5 then
        local u = vel.Unit
        local pp = part.Position
        return Vector3.new(pp.X + u.X * P, pp.Y + u.Y * P, pp.Z + u.Z * P)
    end
    return part.Position
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function hasWallBetween(cam, targetPos)
    if not S.wallCheck then return false end
    local myChar = LocalPlayer.Character
    rayParams.FilterDescendantsInstances = myChar and { myChar } or {}
    local origin = cam.CFrame.Position
    local dir = targetPos - origin
    local dist = dir.Magnitude
    if dist < 0.1 then return false end
    local hit = Workspace:Raycast(origin, dir, rayParams)
    return hit ~= nil and hit.Distance < dist - 0.5
end

local function isValidTarget(p, cam, anchor)
    if not p or p == LocalPlayer then return nil end
    if S.teamCheck and p.Team ~= nil and LocalPlayer.Team ~= nil and p.Team == LocalPlayer.Team then return nil end
    local c = p.Character
    if not c then return nil end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if S.aliveCheck and (not hum or hum.Health <= 0) then return nil end
    if not S.aliveCheck and not hum then return nil end
    local tp = resolvePart(c, S.targetPart)
    if not tp then return nil end
    local tPos = predictPos(tp, c, hum)
    -- FOV gate (functional): nothing outside gets targeted when enabled
    local sp, onScreen, screenDist
    if S.fov then
        sp, onScreen = cam:WorldToViewportPoint(tPos)
        if not onScreen then return nil end
        local dx, dy = sp.X - anchor.X, sp.Y - anchor.Y
        screenDist = SQRT(dx * dx + dy * dy)
        if screenDist > (S.fovSize or 120) then return nil end
    end
    if hasWallBetween(cam, tPos) then return nil end
    return c, hum, tp, tPos, sp, screenDist
end

local locked = nil -- sticky target when Auto Select is off

RunService:BindToRenderStep("bsxd_aim", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not S.aimbot then currentAimPart = nil return end
    local ok = pcall(function()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        local anchor = getFovAnchor(vp)
        local best, bestPos, bestScore = nil, nil, math.huge
        local useFovScore = S.fov
        if S.autoSelect then
            locked = nil
            local allP = Players:GetPlayers()
            for i = 1, #allP do
                local p = allP[i]
                local c, hum, tp, tPos, sp, screenDist = isValidTarget(p, cam, anchor)
                if tp then
                    local score
                    if useFovScore then
                        score = screenDist or 1e9
                    else
                        local pp = tp.Position
                        local cp = cam.CFrame.Position
                        local dx, dy, dz = pp.X - cp.X, pp.Y - cp.Y, pp.Z - cp.Z
                        score = SQRT(dx * dx + dy * dy + dz * dz)
                    end
                    if score < bestScore then best, bestPos, bestScore = tp, tPos, score end
                end
            end
            if best then locked = best end
        else
            -- sticky: keep current lock while still valid, no auto-acquire
            if locked and locked.Parent then
                local lp = Players:GetPlayerFromCharacter(locked.Parent)
                local c, hum, tp, tPos = isValidTarget(lp, cam, anchor)
                if tp and c == locked.Parent then
                    best, bestPos = tp, tPos
                else
                    locked = nil
                end
            else
                locked = nil
            end
        end
        if best and bestPos then
            currentAimPart = best
            -- deadzone: hold still when already on target (looks human, kills micro-shake)
            local dz = S.deadzone or 0
            if dz > 0 then
                local dsp, dOn = cam:WorldToViewportPoint(bestPos)
                if dOn then
                    local ddx, ddy = dsp.X - anchor.X, dsp.Y - anchor.Y
                    if SQRT(ddx * ddx + ddy * ddy) <= dz then return end
                end
            end
            local aimPos = bestPos
            -- humanize: gentle sine wander so streams look legit with visuals off
            if S.humanize then
                local st = S.humanizeStrength or 2
                if st > 0 then
                    local t = tick()
                    local j = st * 0.06
                    aimPos = Vector3.new(aimPos.X + SIN(t * 7.3) * j, aimPos.Y + SIN(t * 9.1 + 1.7) * j, aimPos.Z + COS(t * 6.1) * j)
                end
            end
            local goal = CFrame.new(cam.CFrame.Position, aimPos)
            local sm = S.smoothing or 0
            if sm <= 0 then
                cam.CFrame = goal
            else
                -- dt-corrected exponential smoothing: consistent on 30/60/120+ fps (mobile safe)
                local step = dt or 0.016
                if step <= 0 or step > 0.1 then step = 0.016 end
                local k = 22 / (1 + sm * 2.2)
                local alpha = 1 - EXP(-k * step)
                cam.CFrame = cam.CFrame:Lerp(goal, alpha)
            end
        else
            currentAimPart = nil
        end
    end)
    if not ok then currentAimPart = nil end
end)

-- visuals loop: FOV ring + target tracer (cheap, runs at Last priority)
RunService:BindToRenderStep("bsxd_vis", Enum.RenderPriority.Last.Value, function()
    pcall(function()
        if S.streamproof then
            fovCircle.Visible = false
            fovOutline.Visible = false
            tracerLine.Visible = false
            return
        end
        local cam = Workspace.CurrentCamera
        if not cam then fovCircle.Visible = false fovOutline.Visible = false tracerLine.Visible = false return end
        local vp = cam.ViewportSize
        local center = getFovAnchor(vp)
        local spd = S.rainbowSpeed or 1
        local rainbow = HSV((tick() * spd * 0.25) % 1, 1, 1)
        -- FOV (outline behind main ring, locked color feedback)
        local showFov = S.fov
        local isLocked = currentAimPart ~= nil and currentAimPart.Parent ~= nil
        local lockCol = S.lockedColor or Color3.fromRGB(255, 150, 150)
        fovCircle.Visible = showFov
        fovOutline.Visible = showFov and not S.fovFilled
        if showFov then
            fovCircle.Position = center
            fovCircle.Radius = S.fovSize or 120
            fovCircle.Filled = S.fovFilled or false
            if S.fovFilled then
                fovCircle.Color = (S.fovFillRainbow and rainbow) or (S.fovFillColor or WHITE)
            elseif isLocked then
                fovCircle.Color = lockCol
            else
                fovCircle.Color = S.fovRainbow and rainbow or (S.fovColor or WHITE)
            end
            fovOutline.Position = center
            fovOutline.Radius = S.fovSize or 120
        end
        -- tracer: origin -> current target screen pos
        local tgt = currentAimPart
        local showTracer = S.tracers and tgt ~= nil and tgt.Parent ~= nil
        if showTracer then
            local sp, onScreen = cam:WorldToViewportPoint(tgt.Position)
            if not onScreen then tracerLine.Visible = false return end
            local from
            local org = S.tracerOrigin or "Cursor"
            if org == "Top" then from = V2(vp.X * 0.5, 0)
            elseif org == "Bottom" then from = V2(vp.X * 0.5, vp.Y)
            else
                local ok, mp = pcall(function() return UIS:GetMouseLocation() end)
                from = (ok and mp) and V2(mp.X, mp.Y) or center
            end
            tracerLine.From = from
            tracerLine.To = V2(sp.X, sp.Y)
            tracerLine.Thickness = S.tracerThickness or 2
            if isLocked then
                tracerLine.Color = lockCol
            else
                tracerLine.Color = S.tracerRainbow and rainbow or (S.tracerColor or WHITE)
            end
            tracerLine.Visible = true
        else
            tracerLine.Visible = false
        end
    end)
end)

print("[bsxd] loaded")
