-- BW UI (step 1): custom dark-orange UI shell. Controls only, no features yet.
-- Values live in getgenv().BW_Flags for later wiring.

pcall(function()
    local o = game:GetService("CoreGui"):FindFirstChild("BW_GUI") if o then o:Destroy() end
end)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

getgenv().BW_Flags = getgenv().BW_Flags or {}
local Flags = getgenv().BW_Flags

local ORANGE = Color3.fromRGB(255, 122, 26)
local BG = Color3.fromRGB(18, 18, 22)
local PANEL = Color3.fromRGB(28, 28, 34)
local TEXT = Color3.fromRGB(235, 235, 235)
local DIM = Color3.fromRGB(150, 150, 160)

local sg = Instance.new("ScreenGui")
sg.Name = "BW_GUI"
sg.ResetOnSpawn = false
sg.Parent = game:GetService("CoreGui")

-- main window (draggable, sized for phone + pc)
local win = Instance.new("Frame")
win.Size = UDim2.new(0, 250, 0, 360)
win.Position = UDim2.new(0, 20, 0.5, -180)
win.BackgroundColor3 = BG
win.BorderSizePixel = 0
win.Active = true
win.Draggable = true
win.Parent = sg
local wcorner = Instance.new("UICorner") wcorner.CornerRadius = UDim.new(0, 10) wcorner.Parent = win
local wstroke = Instance.new("UIStroke") wstroke.Color = ORANGE wstroke.Thickness = 1 wstroke.Transparency = 0.4 wstroke.Parent = win

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 0, 34)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Bedwars"
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = ORANGE
title.Parent = win

-- minimize + show/hide (mobile friendly floating re-open)
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 30, 0, 30)
minBtn.Position = UDim2.new(1, -36, 0, 4)
minBtn.BackgroundColor3 = PANEL
minBtn.Text = "-"
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 16
minBtn.TextColor3 = TEXT
minBtn.Parent = win
local mcorner = Instance.new("UICorner") mcorner.CornerRadius = UDim.new(0, 6) mcorner.Parent = minBtn

local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.new(0, 52, 0, 52)
openBtn.Position = UDim2.new(0, 12, 0.5, -26)
openBtn.BackgroundColor3 = ORANGE
openBtn.Text = "BW"
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 16
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.Visible = false
openBtn.Active = true
openBtn.Draggable = true
openBtn.Parent = sg
local ocorner = Instance.new("UICorner") ocorner.CornerRadius = UDim.new(1, 0) ocorner.Parent = openBtn

minBtn.MouseButton1Click:Connect(function() win.Visible = false openBtn.Visible = true end)
openBtn.MouseButton1Click:Connect(function() win.Visible = true openBtn.Visible = false end)

-- scrolling content (fits small phone screens)
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -44)
scroll.Position = UDim2.new(0, 8, 0, 38)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = ORANGE
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = win
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll

local UI = {}

function UI.Section(text)
    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, -4, 0, 20)
    s.BackgroundTransparency = 1
    s.Text = text:upper()
    s.Font = Enum.Font.GothamBold
    s.TextSize = 12
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.TextColor3 = ORANGE
    s.Parent = scroll
end

function UI.Toggle(name, default, cb)
    Flags[name] = default
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -4, 0, 38) -- tall for touch
    b.BackgroundColor3 = PANEL
    b.AutoButtonColor = true
    b.Parent = scroll
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = b
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -58, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = TEXT
    lbl.Parent = b
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 18, 0, 18)
    dot.Position = UDim2.new(1, -30, 0.5, -9)
    dot.BackgroundColor3 = default and ORANGE or Color3.fromRGB(60, 60, 70)
    dot.Parent = b
    local dc = Instance.new("UICorner") dc.CornerRadius = UDim.new(1, 0) dc.Parent = dot
    local function ref() dot.BackgroundColor3 = Flags[name] and ORANGE or Color3.fromRGB(60, 60, 70) end
    b.MouseButton1Click:Connect(function()
        Flags[name] = not Flags[name]
        ref()
        if cb then pcall(cb, Flags[name]) end
    end)
    ref()
    return function(v) Flags[name] = v ref() if cb then pcall(cb, v) end end
end

function UI.Slider(name, min, max, default, cb)
    Flags[name] = default
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -4, 0, 52)
    holder.BackgroundColor3 = PANEL
    holder.Parent = scroll
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = holder
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = TEXT
    lbl.Parent = holder
    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(1, -20, 0, 14)
    bar.Position = UDim2.new(0, 10, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    bar.Text = ""
    bar.AutoButtonColor = false
    bar.Parent = holder
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1, 0) bc.Parent = bar
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = ORANGE
    fill.BorderSizePixel = 0
    fill.Parent = bar
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1, 0) fc.Parent = fill
    local function ref()
        lbl.Text = name .. ": " .. string.format("%.1f", Flags[name])
        fill.Size = UDim2.new(math.clamp((Flags[name] - min) / (max - min), 0, 1), 0, 1, 0)
    end
    local dragging = false
    local function slide(x)
        local ax, aw = bar.AbsolutePosition.X, bar.AbsoluteSize.X
        local t = math.clamp((x - ax) / math.max(aw, 1), 0, 1)
        Flags[name] = min + t * (max - min)
        ref()
        if cb then pcall(cb, Flags[name]) end
    end
    bar.MouseButton1Down:Connect(function(x) dragging = true slide(x) end)
    game:GetService("UserInputService").InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            slide(i.Position.X)
        end
    end)
    ref()
end

function UI.ColorPicker(name, default, cb)
    Flags[name] = default or ORANGE
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -4, 0, 0)
    holder.BackgroundColor3 = PANEL
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.Parent = scroll
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = holder
    local top = Instance.new("TextButton")
    top.Size = UDim2.new(1, 0, 0, 38)
    top.BackgroundTransparency = 1
    top.Text = ""
    top.Parent = holder
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -58, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = TEXT
    lbl.Parent = top
    local sw = Instance.new("Frame")
    sw.Size = UDim2.new(0, 26, 0, 26)
    sw.Position = UDim2.new(1, -36, 0.5, -13)
    sw.BackgroundColor3 = Flags[name]
    sw.Parent = top
    local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(0, 6) sc.Parent = sw
    -- preset swatches
    local presets = {
        Color3.fromRGB(255, 122, 26), Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 220, 60),
        Color3.fromRGB(80, 255, 120), Color3.fromRGB(80, 170, 255), Color3.fromRGB(180, 100, 255),
        Color3.fromRGB(255, 255, 255), Color3.fromRGB(20, 20, 20),
    }
    local grid = Instance.new("Frame")
    grid.Size = UDim2.new(1, -20, 0, 34)
    grid.Position = UDim2.new(0, 10, 0, 40)
    grid.BackgroundTransparency = 1
    grid.Visible = false
    grid.Parent = holder
    local gl = Instance.new("UIGridLayout")
    gl.CellSize = UDim2.new(0, 26, 0, 26)
    gl.CellPadding = UDim2.new(0, 6, 0, 6)
    gl.Parent = grid
    local pad = Instance.new("UIPadding") -- space for rgb sliders below
    pad.Parent = holder
    local rgbH = Instance.new("Frame")
    rgbH.Size = UDim2.new(1, -20, 0, 0)
    rgbH.Position = UDim2.new(0, 10, 0, 80)
    rgbH.BackgroundTransparency = 1
    rgbH.Visible = false
    rgbH.Parent = holder
    local rl = Instance.new("UIListLayout") rl.Padding = UDim.new(0, 4) rl.Parent = rgbH
    local function rgbSlider(comp, label)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 22)
        b.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        b.Text = ""
        b.AutoButtonColor = false
        b.Parent = rgbH
        local bc2 = Instance.new("UICorner") bc2.CornerRadius = UDim.new(1, 0) bc2.Parent = b
        local fl = Instance.new("Frame")
        fl.BackgroundColor3 = comp == 1 and Color3.fromRGB(255, 80, 80) or (comp == 2 and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(80, 170, 255))
        fl.BorderSizePixel = 0
        fl.Parent = b
        local fc2 = Instance.new("UICorner") fc2.CornerRadius = UDim.new(1, 0) fc2.Parent = fl
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(0, 20, 1, 0)
        t.BackgroundTransparency = 1
        t.Text = label
        t.Font = Enum.Font.GothamBold
        t.TextSize = 12
        t.TextColor3 = TEXT
        t.Parent = b
        local function ref()
            fl.Size = UDim2.new(Flags[name][comp], 0, 1, 0)
        end
        local function set(x)
            local ax, aw = b.AbsolutePosition.X, b.AbsoluteSize.X
            local v = math.clamp((x - ax) / math.max(aw, 1), 0, 1)
            local r, g, bl = Flags[name].R, Flags[name].G, Flags[name].B
            if comp == 1 then r = v elseif comp == 2 then g = v else bl = v end
            Flags[name] = Color3.new(r, g, bl)
            sw.BackgroundColor3 = Flags[name]
            ref()
            if cb then pcall(cb, Flags[name]) end
        end
        b.MouseButton1Down:Connect(set)
        ref()
    end
    rgbSlider(1, "R") rgbSlider(2, "G") rgbSlider(3, "B")
    local open = false
    top.MouseButton1Click:Connect(function()
        open = not open
        grid.Visible = open
        rgbH.Visible = open
        rgbH.Size = UDim2.new(1, -20, 0, open and 82 or 0)
    end)
    for _, col in ipairs(presets) do
        local s = Instance.new("TextButton")
        s.BackgroundColor3 = col
        s.Text = ""
        s.Parent = grid
        local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(1, 0) cc.Parent = s
        s.MouseButton1Click:Connect(function()
            Flags[name] = col
            sw.BackgroundColor3 = col
            if cb then pcall(cb, col) end
        end)
    end
end

-- demo controls (proves wiring; real features come with your remotes)
UI.Section("Combat")
UI.Toggle("KillAura", false)
UI.Slider("AuraRange", 5, 30, 16)
UI.ColorPicker("EspColor", ORANGE)
UI.Section("Movement")
UI.Toggle("Fly", false)
UI.Slider("FlySpeed", 10, 150, 50)

getgenv().BW_UI = UI
print("[BW] ui loaded")
