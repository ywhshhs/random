-- VehicleTP: teleport 5k studs forward on keypress.
-- Server rubber-bands vehicles after 1-6s, so you get a few seconds wherever you land.
-- Works on foot + seated (moves the vehicle model too). PC key + mobile button.

local DIST = 5000
local KEY = Enum.KeyCode.T
local DEBOUNCE = 0.5

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local lastGo = 0

local function go()
    if tick() - lastGo < DEBOUNCE then return end
    lastGo = tick()
    local c = LP.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if not h or not hum or hum.Health <= 0 then return end
    -- direction of travel (flattened so you don't launch into the sky/ground)
    local dir = hum.MoveDirection
    if dir.Magnitude < 0.1 then
        local lv = h.CFrame.LookVector
        dir = Vector3.new(lv.X, 0, lv.Z)
        if dir.Magnitude < 0.01 then dir = Vector3.new(0, 0, -1) end
        dir = dir.Unit
    end
    local off = dir * DIST
    pcall(function()
        h.AssemblyLinearVelocity = Vector3.zero
        h.AssemblyAngularVelocity = Vector3.zero
        if hum.Seated and hum.SeatPart then
            -- move the vehicle too, then re-seat yourself inside it
            local veh = hum.SeatPart:FindFirstAncestorOfClass("Model")
            if veh and veh.PrimaryPart then
                veh:PivotTo(veh.PrimaryPart.CFrame + off)
                for _, p in ipairs(veh:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.AssemblyLinearVelocity = Vector3.zero
                        p.AssemblyAngularVelocity = Vector3.zero
                    end
                end
            end
        end
        c:PivotTo(h.CFrame + off)
    end)
    print("[TP] +" .. DIST .. " studs")
end

UIS.InputBegan:Connect(function(inp, gpe)
    if not gpe and inp.KeyCode == KEY then go() end
end)

-- mobile button (draggable, always on top)
local sg = Instance.new("ScreenGui")
sg.Name = "VehicleTP_GUI"
sg.ResetOnSpawn = false
sg.Parent = game:GetService("CoreGui")
local b = Instance.new("TextButton")
b.Size = UDim2.new(0, 64, 0, 64)
b.Position = UDim2.new(1, -80, 0.6, 0)
b.BackgroundColor3 = Color3.fromRGB(255, 122, 26)
b.Text = "5K"
b.Font = Enum.Font.GothamBold
b.TextSize = 20
b.TextColor3 = Color3.new(1, 1, 1)
b.Active = true
b.Draggable = true
b.Parent = sg
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(1, 0)
bc.Parent = b
b.MouseButton1Click:Connect(go)

print("[TP] loaded: press " .. tostring(KEY) .. " or tap 5K (" .. DIST .. " studs)")
