-- BW (Thugsense/synca UI shell): dark-orange, mobile+PC. Controls only, no features yet.

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/ywhshhs/synca/main/Thugsense/Library.lua"))()

local Window = Library:Window({
    Name = "Bedwars",
    FadeSpeed = 0.25,
})

-- dark orange theme over the default dark base
Library:ChangeTheme("Accent", Color3.fromHex("#ff7a1a"))

local Watermark = Library:Watermark("bedwars ~ " .. os.date("%b %d %Y"))
local KeybindList = Library:KeybindList()
Watermark:SetVisibility(true)
KeybindList:SetVisibility(false)

local CombatTab = Window:Page({ Name = "Combat", Columns = 2, Subtabs = false })
local MovementTab = Window:Page({ Name = "Movement", Columns = 2, Subtabs = false })
local VisualsTab = Window:Page({ Name = "Visuals", Columns = 2, Subtabs = false })
local SettingsTab = Library:CreateSettingsPage(Window, Watermark, KeybindList)

do -- Combat (demo wiring; real logic lands with the remotes)
    local AuraSection = CombatTab:Section({ Name = "Kill Aura", Side = 1 })
    AuraSection:Toggle({ Name = "Enabled", Flag = "KillAura", Default = false, Callback = function(v) print("KillAura", v) end })
    AuraSection:Slider({ Name = "Range", Min = 5, Max = 30, Default = 16, Suffix = "st", Decimals = 1, Flag = "AuraRange", Callback = function(v) print("AuraRange", v) end })

    local TargetSection = CombatTab:Section({ Name = "Target", Side = 2 })
    TargetSection:Toggle({ Name = "Team Check", Flag = "TeamCheck", Default = true, Callback = function(v) print("TeamCheck", v) end })
    TargetSection:Toggle({ Name = "Wall Check", Flag = "WallCheck", Default = true, Callback = function(v) print("WallCheck", v) end })
end

do -- Movement (demo wiring)
    local FlySection = MovementTab:Section({ Name = "Fly", Side = 1 })
    FlySection:Toggle({ Name = "Enabled", Flag = "Fly", Default = false, Callback = function(v) print("Fly", v) end })
    FlySection:Slider({ Name = "Speed", Min = 10, Max = 150, Default = 50, Suffix = "st/s", Decimals = 0, Flag = "FlySpeed", Callback = function(v) print("FlySpeed", v) end })
end

do -- Visuals (demo wiring)
    local EspSection = VisualsTab:Section({ Name = "ESP", Side = 1 })
    EspSection:Toggle({ Name = "Enabled", Flag = "ESP", Default = false, Callback = function(v) print("ESP", v) end })
    :Colorpicker({ Name = "ESP Color", Flag = "EspColor", Default = Color3.fromHex("#ff7a1a"), Callback = function(v) print("EspColor", v) end })
end

getgenv().BW_Lib = Library
print("[BW] thugsense ui loaded")
