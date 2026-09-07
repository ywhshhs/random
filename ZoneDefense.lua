-- ZD fresh (step 1): bare UI shell only, no features yet.

pcall(function()
    local o = game:GetService("CoreGui"):FindFirstChild("ZD_GUI") if o then o:Destroy() end
end)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

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

print("[ZD] ui shell loaded")
