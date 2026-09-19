-- ZenExecutor Mobile v1.0 (self-contained, no HttpGet)
local Players = game:GetService("Players")
local LogService = game:GetService("LogService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("ZenExecutor") then playerGui.ZenExecutor:Destroy() end

local C = {
	bgMain = Color3.fromRGB(22,22,26), bgPanel = Color3.fromRGB(28,28,33),
	bgSub = Color3.fromRGB(16,16,19), border = Color3.fromRGB(55,55,65),
	text = Color3.fromRGB(225,225,235), gray = Color3.fromRGB(150,150,165),
	accent = Color3.fromRGB(110,170,255), green = Color3.fromRGB(55,180,90),
	red = Color3.fromRGB(200,55,55), yellow = Color3.fromRGB(240,200,40),
	blue = Color3.fromRGB(45,110,200),
}

local gui = Instance.new("ScreenGui")
gui.Name = "ZenExecutor" gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999 gui.IgnoreGuiInset = true gui.Parent = playerGui

local uiScale = Instance.new("UIScale", gui)
local function fit()
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1000,600)
	uiScale.Scale = math.clamp(math.min(vp.X/900, vp.Y/620, 1), 0.55, 1)
end
fit() workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

local main = Instance.new("Frame", gui)
main.AnchorPoint = Vector2.new(0.5,0.5) main.Position = UDim2.new(0.5,0,0.5,0)
main.Size = UDim2.new(0.94,0,0.82,0) main.BackgroundColor3 = C.bgMain
main.BorderSizePixel = 1 main.BorderColor3 = C.border main.Active = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0,10)

local titleBar = Instance.new("Frame", main)
titleBar.Size = UDim2.new(1,0,0,38) titleBar.BackgroundColor3 = C.bgPanel titleBar.BorderSizePixel = 0
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0,10)

local title = Instance.new("TextLabel", titleBar)
title.Size = UDim2.new(1,-100,1,0) title.Position = UDim2.new(0,12,0,0)
title.BackgroundTransparency = 1 title.Text = "Zen Executor - mobile ready"
title.TextColor3 = C.text title.Font = Enum.Font.GothamBold title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left

local function titleBtn(txt, off)
	local b = Instance.new("TextButton", titleBar)
	b.Size = UDim2.new(0,38,0,28) b.Position = UDim2.new(1,off,0.5,-14)
	b.BackgroundColor3 = Color3.fromRGB(70,70,85) b.TextColor3 = Color3.new(1,1,1)
	b.Font = Enum.Font.GothamBold b.TextSize = 16 b.Text = txt
	Instance.new("UICorner", b).CornerRadius = UDim.new(0,6) return b
end
local minBtn = titleBtn("-", -86)

-- touch + mouse drag
do
	local dragging, dStart, sPos = false, nil, nil
	titleBar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, dStart, sPos = true, i.Position, main.Position
			i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dStart
			main.Position = UDim2.new(sPos.X.Scale, sPos.X.Offset + d.X, sPos.Y.Scale, sPos.Y.Offset + d.Y)
		end
	end)
end

local toolBar = Instance.new("Frame", main)
toolBar.Size = UDim2.new(1,-16,0,44) toolBar.Position = UDim2.new(0,8,0,44) toolBar.BackgroundTransparency = 1
local tl = Instance.new("UIListLayout", toolBar)
tl.FillDirection = Enum.FillDirection.Horizontal tl.Padding = UDim.new(0,6)
local function btn(txt, bg)
	local b = Instance.new("TextButton", toolBar)
	b.Size = UDim2.new(0,86,0,38) b.BackgroundColor3 = bg b.TextColor3 = Color3.new(1,1,1)
	b.Font = Enum.Font.GothamBold b.TextSize = 13 b.Text = txt
	Instance.new("UICorner", b).CornerRadius = UDim.new(0,7) return b
end
local execBtn, clearBtn, copyBtn = btn("> Run", C.green), btn("Clear", Color3.fromRGB(70,70,85)), btn("Copy", Color3.fromRGB(70,70,85))
local saveBtn, openBtn, consBtn = btn("Save", C.blue), btn("Open", Color3.fromRGB(90,70,150)), btn("Console", Color3.fromRGB(70,70,85))

local fileBox = Instance.new("TextBox", main)
fileBox.Size = UDim2.new(1,-16,0,30) fileBox.Position = UDim2.new(0,8,0,92)
fileBox.BackgroundColor3 = C.bgSub fileBox.BorderSizePixel = 1 fileBox.BorderColor3 = C.border
fileBox.TextColor3 = C.text fileBox.PlaceholderColor3 = C.gray
fileBox.PlaceholderText = "filename.lua  (save=open via writefile/readfile)" fileBox.Text = "script.lua"
fileBox.Font = Enum.Font.Code fileBox.TextSize = 13 fileBox.ClearTextOnFocus = false
Instance.new("UICorner", fileBox).CornerRadius = UDim.new(0,6)

local fileList = Instance.new("ScrollingFrame", main)
fileList.Size = UDim2.new(0,240,0,180) fileList.Position = UDim2.new(1,-256,0,128)
fileList.BackgroundColor3 = C.bgPanel fileList.BorderSizePixel = 1 fileList.BorderColor3 = C.border
fileList.ScrollBarThickness = 4 fileList.AutomaticCanvasSize = Enum.AutomaticSize.Y
fileList.Visible = false fileList.ZIndex = 50
Instance.new("UIListLayout", fileList).Padding = UDim.new(0,2)

local editorWrap = Instance.new("Frame", main)
editorWrap.Size = UDim2.new(1,-16,1,-262) editorWrap.Position = UDim2.new(0,8,0,130)
editorWrap.BackgroundColor3 = C.bgSub editorWrap.BorderSizePixel = 1 editorWrap.BorderColor3 = C.border
editorWrap.ClipsDescendants = true
Instance.new("UICorner", editorWrap).CornerRadius = UDim.new(0,6)

local lineNums = Instance.new("TextLabel", editorWrap)
lineNums.Size = UDim2.new(0,42,0,10000) lineNums.BackgroundColor3 = Color3.fromRGB(12,12,15)
lineNums.TextColor3 = C.gray lineNums.Font = Enum.Font.Code lineNums.TextSize = 13
lineNums.TextXAlignment = Enum.TextXAlignment.Center lineNums.TextYAlignment = Enum.TextYAlignment.Top lineNums.Text = "1"

local editorScroll = Instance.new("ScrollingFrame", editorWrap)
editorScroll.Size = UDim2.new(1,-42,1,0) editorScroll.Position = UDim2.new(0,42,0,0)
editorScroll.BackgroundTransparency = 1 editorScroll.BorderSizePixel = 0 editorScroll.ScrollBarThickness = 5
local hlHolder = Instance.new("Frame", editorScroll)
hlHolder.Size = UDim2.new(1,0,1,0) hlHolder.BackgroundTransparency = 1
local editorBox = Instance.new("TextBox", editorScroll)
editorBox.Size = UDim2.new(1,0,1,0) editorBox.BackgroundTransparency = 1 editorBox.ClearTextOnFocus = false
editorBox.MultiLine = true editorBox.TextXAlignment = Enum.TextXAlignment.Left editorBox.TextYAlignment = Enum.TextYAlignment.Top
editorBox.TextColor3 = Color3.new(1,1,1) editorBox.TextTransparency = 0.55
editorBox.Font = Enum.Font.Code editorBox.TextSize = 13
editorBox.Text = "-- Zen ready.\nprint(\"Hello from mobile!\")"

local consoleWrap = Instance.new("Frame", main)
consoleWrap.Size = UDim2.new(1,-16,0,118) consoleWrap.Position = UDim2.new(0,8,1,-126)
consoleWrap.BackgroundColor3 = Color3.fromRGB(10,10,13) consoleWrap.BorderSizePixel = 1 consoleWrap.BorderColor3 = C.border
Instance.new("UICorner", consoleWrap).CornerRadius = UDim.new(0,6)
local cHead = Instance.new("Frame", consoleWrap)
cHead.Size = UDim2.new(1,0,0,26) cHead.BackgroundColor3 = C.bgPanel cHead.BorderSizePixel = 0
local cTitle = Instance.new("TextLabel", cHead)
cTitle.Size = UDim2.new(1,-120,1,0) cTitle.Position = UDim2.new(0,8,0,0) cTitle.BackgroundTransparency = 1
cTitle.Text = "Console - live output" cTitle.TextColor3 = C.gray cTitle.Font = Enum.Font.GothamBold cTitle.TextSize = 12
cTitle.TextXAlignment = Enum.TextXAlignment.Left
local cClear = Instance.new("TextButton", cHead)
cClear.Size = UDim2.new(0,52,0,20) cClear.Position = UDim2.new(1,-60,0.5,-10)
cClear.BackgroundColor3 = Color3.fromRGB(70,70,85) cClear.TextColor3 = Color3.new(1,1,1)
cClear.Font = Enum.Font.GothamBold cClear.TextSize = 11 cClear.Text = "Clear"
Instance.new("UICorner", cClear).CornerRadius = UDim.new(0,5)
local cScroll = Instance.new("ScrollingFrame", consoleWrap)
cScroll.Size = UDim2.new(1,-8,1,-30) cScroll.Position = UDim2.new(0,4,0,28)
cScroll.BackgroundTransparency = 1 cScroll.BorderSizePixel = 0 cScroll.ScrollBarThickness = 4
cScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UIListLayout", cScroll).Padding = UDim.new(0,2)

local function atBottom()
	local ok, r = pcall(function()
		return cScroll.CanvasPosition.Y + cScroll.AbsoluteWindowSize.Y >= cScroll.CanvasSize.Y.Offset - 30
	end) return (not ok) or r
end
local function addCon(txt, col)
	local was = atBottom()
	local l = Instance.new("TextLabel", cScroll)
	l.Size = UDim2.new(1,-6,0,16) l.AutomaticSize = Enum.AutomaticSize.Y l.BackgroundTransparency = 1
	l.TextColor3 = col or C.text l.Font = Enum.Font.Code l.TextSize = 12
	l.TextXAlignment = Enum.TextXAlignment.Left l.TextWrapped = true l.Text = tostring(txt)
	if was then task.defer(function()
		pcall(function() cScroll.CanvasPosition = Vector2.new(0, math.max(0, cScroll.CanvasSize.Y.Offset - cScroll.AbsoluteWindowSize.Y)) end)
	end) end
end
cClear.Activated:Connect(function() for _,v in ipairs(cScroll:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end end)
LogService.MessageOut:Connect(function(msg, t)
	if t == Enum.MessageType.MessageWarning then addCon("[WARN] "..msg, C.yellow)
	elseif t == Enum.MessageType.MessageError then addCon("[ERROR] "..msg, Color3.fromRGB(255,85,85))
	elseif t == Enum.MessageType.MessageInfo then addCon("[INFO] "..msg, C.gray)
	else addCon(msg, Color3.fromRGB(235,235,245)) end
end)
addCon("Console attached. print=white warn=yellow error=red", C.gray)

-- syntax highlight (debounced so mobile doesn't lag)
local KW = {["and"]=1,["break"]=1,["do"]=1,["else"]=1,["elseif"]=1,["end"]=1,["for"]=1,["function"]=1,["if"]=1,["in"]=1,["local"]=1,["not"]=1,["or"]=1,["repeat"]=1,["return"]=1,["then"]=1,["until"]=1,["while"]=1}
local BI = {game=1,workspace=1,script=1,Instance=1,UDim2=1,Vector3=1,CFrame=1,Color3=1,Enum=1,task=1,table=1,string=1,math=1,print=1,warn=1,error=1,pcall=1,pairs=1,ipairs=1,tostring=1,tonumber=1,type=1,require=1,loadstring=1}
local SC = {Text="#d4d4d4",Number="#ffc600",String="#adf195",Comment="#6e6e6e",Keyword="#f86d7c",BuiltIn="#84d6f7",Func="#fdfbac"}
local blockC = false
local AMP = string.char(38)
local function esc(s)
	s = s:gsub(AMP, AMP.."amp;")
	s = s:gsub("<", AMP.."lt;")
	s = s:gsub(">", AMP.."gt;")
	return s
end
local function hiLine(line)
	local out, i, toks = "", 1, {}
	local function push(t, k) table.insert(toks, {t,k}) end
	if blockC then local e = line:find("]]",1,true) if e then push(line:sub(1,e+1),"Comment") blockC=false i=e+2 else return string.format('<font color="%s">%s</font>', SC.Comment, esc(line)) end end
	while i <= #line do
		local c = line:sub(i,i)
		if c=="-" and line:sub(i,i+3)=="-- [[" or line:sub(i,i+1)=="--" then push(line:sub(i),"Comment") break
		elseif c=='"' or c=="'" then local j=i+1 while j<=#line and line:sub(j,j)~=c do j=j+1 end push(line:sub(i,math.min(j,#line)),"String") i=math.min(j,#line)+1
		elseif c:match("%d") then local j=i while j<=#line and line:sub(j,j):match("[%d%.]") do j=j+1 end push(line:sub(i,j-1),"Number") i=j
		elseif c:match("[%a_]") then local j=i while j<=#line and line:sub(j,j):match("[%w_]") do j=j+1 end push(line:sub(i,j-1),"Word") i=j
		else push(c,"Op") i=i+1 end
	end
	for n,t in ipairs(toks) do
		local k = t[2]
		if k=="Word" then if KW[t[1]] then k="Keyword" elseif BI[t[1]] then k="BuiltIn" elseif t[1]=="true" or t[1]=="false" or t[1]=="nil" then k="Number" elseif toks[n+1] and toks[n+1][1]=="(" then k="Func" else k="Text" end end
		local col = SC[k] or SC.Text
		out = out .. string.format('<font color="%s">%s</font>', col, esc(t[1]))
	end
	return out
end
local dirty = false
local function refresh()
	if dirty then return end dirty = true
	task.delay(0.2, function()
		dirty = false for _,v in ipairs(hlHolder:GetChildren()) do v:Destroy() end blockC = false
		local lines, n = {}, 0
		for l in ((editorBox.Text or "").."\n"):gmatch("([^\n]*)\n") do n=n+1 if n>800 then break end table.insert(lines,l) end
		local y, wid = 0, 0 for _,l in ipairs(lines) do wid = math.max(wid, #l) end
		local cw = math.max(editorScroll.AbsoluteSize.X-10, wid*7.2+20)
		for _,l in ipairs(lines) do
			local lb = Instance.new("TextLabel", hlHolder)
			lb.Size = UDim2.new(0,cw,0,17) lb.Position = UDim2.new(0,4,0,y) lb.BackgroundTransparency = 1
			lb.Font = Enum.Font.Code lb.TextSize = 13 lb.TextXAlignment = Enum.TextXAlignment.Left
			lb.RichText = true lb.Text = hiLine(l ~= "" and l or " ") y = y + 17
		end
		local b = {} for i=1,#lines do b[i]=tostring(i) end lineNums.Text = table.concat(b,"\n")
		local h = math.max(y+40, editorWrap.AbsoluteSize.Y)
		editorBox.Size = UDim2.new(0,cw,0,h) hlHolder.Size = UDim2.new(0,cw,0,h)
		editorScroll.CanvasSize = UDim2.new(0,cw,0,h)
	end)
end
editorBox:GetPropertyChangedSignal("Text"):Connect(refresh)
editorScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
	pcall(function() lineNums.Position = UDim2.new(0,0,0,-editorScroll.CanvasPosition.Y) end)
end)
task.defer(refresh)

execBtn.Activated:Connect(function()
	local fn, err = loadstring(editorBox.Text or "")
	if not fn then addCon("[ERROR] Syntax: "..tostring(err), Color3.fromRGB(255,85,85)) return end
	local ok, r = pcall(fn)
	if not ok then addCon("[ERROR] Runtime: "..tostring(r), Color3.fromRGB(255,85,85))
	elseif r ~= nil then addCon("-> "..tostring(r), C.gray) else addCon("Done.", C.green) end
end)
clearBtn.Activated:Connect(function() editorBox.Text = "" refresh() end)
copyBtn.Activated:Connect(function() pcall(function() setclipboard(editorBox.Text) end) end)
saveBtn.Activated:Connect(function()
	local n = fileBox.Text ~= "" and fileBox.Text or "script.lua"
	local ok, e = pcall(function() writefile(n, editorBox.Text or "") end)
	addCon(ok and ("Saved "..n) or ("[ERROR] writefile: "..tostring(e)), ok and C.green or Color3.fromRGB(255,85,85))
end)
openBtn.Activated:Connect(function()
	if not fileList.Visible then
		local n = (fileBox.Text or ""):gsub("^%s+",""):gsub("%s+$","")
		if n ~= "" then local ok, c = pcall(function() return readfile(n) end) if ok and type(c)=="string" then editorBox.Text=c refresh() addCon("Opened "..n, C.green) return end end
		for _,v in ipairs(fileList:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
		local ok, files = pcall(function() return listfiles("") end)
		if ok and type(files)=="table" then
			for _,p in ipairs(files) do if p:match("%.lua$") or p:match("%.txt$") then
				local b = Instance.new("TextButton", fileList)
				b.Size = UDim2.new(1,-4,0,28) b.BackgroundColor3 = C.bgSub b.TextColor3 = C.text
				b.Font = Enum.Font.Code b.TextSize = 12 b.TextXAlignment = Enum.TextXAlignment.Left b.Text = " "..p
				b.Activated:Connect(function()
					local o2, c2 = pcall(function() return readfile(p) end)
					if o2 then editorBox.Text=c2 fileBox.Text=p:match("([^/\\]+)$") or p refresh() fileList.Visible=false end
				end)
			end end
		end
		fileList.Visible = true
	else fileList.Visible = false end
end)
local cOpen = true
consBtn.Activated:Connect(function()
	cOpen = not cOpen consoleWrap.Visible = cOpen
	editorWrap.Size = cOpen and UDim2.new(1,-16,1,-262) or UDim2.new(1,-16,1,-136) refresh()
end)
local mini = false
minBtn.Activated:Connect(function()
	mini = not mini editorWrap.Visible = not mini consoleWrap.Visible = (not mini) and cOpen
	toolBar.Visible, fileBox.Visible = not mini, not mini
	main.Size = mini and UDim2.new(0.94,0,0,42) or UDim2.new(0.94,0,0.82,0) minBtn.Text = mini and "+" or "-"
end)
print("[ZenExecutor] loaded")
