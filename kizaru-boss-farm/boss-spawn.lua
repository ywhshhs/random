-- Auto Boss Spawn & Attack
-- Clicks KizaruReduceTime every 1s until boss spawns, then teleports behind & attacks

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Paths
local bossSpawn = Workspace.Map["Boss Spawn"]["Kizaru Boss[Lv.425]"]
local reduceTimeNPC = Workspace.Map.NPCs.KizaruReduceTime
local attackRemote = ReplicatedStorage.Remotes.RemoteEvents.Skills.Move

-- Config
local ATTACK_DELAY = 0.5 -- delay after spawning before attacking
local ATTACK_REPEAT = 0.2 -- time between attack swings

-- State
local enabled = false
local lastPosition = nil

-- GUI Toggle (top center)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BossAuto_Toggle"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 160, 0, 40)
toggleBtn.Position = UDim2.new(0.5, -80, 0, 10)
toggleBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Text = "Boss Auto: OFF"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 14
toggleBtn.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = toggleBtn

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 250, 0, 25)
statusLabel.Position = UDim2.new(0.5, -125, 0, 55)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.Text = "Status: Idle"
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.Parent = screenGui

-- Teleport to NPC to be in range of proximity prompt
local function teleportToNPC()
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Try to find a part in the NPC to stand on
    local npcPart = reduceTimeNPC.PrimaryPart or reduceTimeNPC:FindFirstChildWhichIsA("BasePart")
    if npcPart then
        local offset = npcPart.CFrame * CFrame.new(2, 0, 0) -- stand next to it
        lastPosition = offset.Position
        hrp.CFrame = offset
    end
end

-- Fire proximity prompt
local function fireReduceTime()
    -- Teleport to NPC first so we're in range
    teleportToNPC()
    task.wait(0.15)

    local prompt = reduceTimeNPC:FindFirstChildWhichIsA("ProximityPrompt")
        or reduceTimeNPC:FindFirstChildWhichIsA("ClickDetector")
    if prompt then
        if prompt:IsA("ProximityPrompt") then
            fireproximityprompt(prompt)
        elseif prompt:IsA("ClickDetector") then
            prompt:MouseClick()
        end
    end
end

-- Teleport behind boss
local function teleportBehindBoss(bossPart)
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local behindPos = bossPart.CFrame * CFrame.new(0, 0, 3)
    lastPosition = behindPos.Position
    hrp.CFrame = behindPos
end

-- Attack loop
local function attackBoss()
    while enabled do
        local exists, bossPart = bossExists()
        if not exists then break end

        local character = player.Character
        if not character then break end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then break end

        -- Keep teleporting behind
        teleportBehindBoss(bossPart)
        task.wait(0.05)

        -- Fire attack
        attackRemote:FireServer("Katana", "Katana")
        task.wait(ATTACK_REPEAT)
    end
end

-- Check if boss exists
local function bossExists()
    if not bossSpawn or not bossSpawn.Parent then return false, nil end

    -- Find the actual boss part inside the model
    local bossPart = bossSpawn:FindFirstChild("HumanoidRootPart")
        or bossSpawn:FindFirstChildWhichIsA("BasePart")
        or bossSpawn.PrimaryPart

    if bossPart then
        return true, bossPart
    end

    -- If bossSpawn itself is a BasePart
    if bossSpawn:IsA("BasePart") then
        return true, bossSpawn
    end

    return false, nil
end

-- Main loop
local function mainLoop()
    while enabled do
        local exists, bossPart = bossExists()

        if not exists then
            -- Boss not spawned, click reduce time every 1s
            statusLabel.Text = "Status: Waiting for boss... Clicking reduce time"
            task.wait(1)
            if enabled then
                fireReduceTime()
            end
            task.wait(0.1)
        else
            -- Boss spawned! Teleport behind and attack
            statusLabel.Text = "Status: Boss found! Attacking..."
            task.wait(ATTACK_DELAY)
            teleportBehindBoss(bossPart)
            task.wait(0.1)
            attackBoss()

            -- After attack loop ends (boss dead or despawned), continue cycle
            statusLabel.Text = "Status: Boss defeated. Restarting..."
            task.wait(1)
        end
    end
    statusLabel.Text = "Status: Idle"
end

-- Toggle
local function toggle()
    enabled = not enabled
    toggleBtn.Text = enabled and "Boss Auto: ON" or "Boss Auto: OFF"
    toggleBtn.BackgroundColor3 = enabled and Color3.fromRGB(40, 180, 40) or Color3.fromRGB(180, 40, 40)

    if enabled then
        print("Boss Auto: ENABLED")
        task.spawn(mainLoop)
    else
        print("Boss Auto: DISABLED")
    end
end

toggleBtn.MouseButton1Click:Connect(toggle)
print("Boss Auto loaded. Click button to toggle.")
