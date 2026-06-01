local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local ANIM_ID = "rbxassetid://109030594660124"
local DEFAULT_HEIGHT = 15

local activePlatform = nil
local activeTrack = nil
local walkConnection = nil
local poseConnection = nil
local isWalkMode = false
local currentHeight = DEFAULT_HEIGHT
local isActive = false

local function getCharParts()
	local character = player.Character
	if not character then return nil, nil, nil, nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or humanoid:CreateChild("Animator"))
	return character, root, humanoid, animator
end

local function loadAndPlayAnim(animator)
	local animation = Instance.new("Animation")
	animation.AnimationId = ANIM_ID
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	task.wait(0.05)
	track:Play()
	return track
end

local function cleanUp()
	if poseConnection then poseConnection:Disconnect() poseConnection = nil end
	if walkConnection then walkConnection:Disconnect() walkConnection = nil end
	if activeTrack then activeTrack:Stop() activeTrack = nil end
	if activePlatform then activePlatform:Destroy() activePlatform = nil end

	local _, root, humanoid, _ = getCharParts()
	if humanoid then
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	isWalkMode = false
	isActive = false
end

local function makePlatform()
	local p = Instance.new("Part")
	p.Name = "FlexPlatform"
	p.Size = Vector3.new(14, 1, 14)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = true
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = workspace
	return p
end

local function getFloor(character, exclude)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local rayParams = RaycastParams.new()
	local filter = {character}
	if exclude then table.insert(filter, exclude) end
	rayParams.FilterDescendantsInstances = filter
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(root.Position, Vector3.new(0, -300, 0), rayParams)
	return result and result.Position.Y or (root.Position.Y - 5)
end

local function startPose(height)
	cleanUp()
	local character, root, humanoid, animator = getCharParts()
	if not root or not animator then return end

	currentHeight = height
	isActive = true

	local floorY = getFloor(character, nil)
	activePlatform = makePlatform()
	activePlatform.CFrame = CFrame.new(root.Position.X, floorY + height, root.Position.Z)

	local facing = CFrame.new(Vector3.new(), Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z))
	root.CFrame = CFrame.new(root.Position.X, floorY + height + 3.5, root.Position.Z) * facing

	humanoid.PlatformStand = true
	activeTrack = loadAndPlayAnim(animator)

	local savedFloor = floorY
	poseConnection = RunService.Heartbeat:Connect(function()
		if not root or not root.Parent or not activePlatform then cleanUp() return end
		local px, pz = root.Position.X, root.Position.Z
		local targetY = savedFloor + currentHeight + 3.5
		local lv = root.CFrame.LookVector
		local yaw = CFrame.new(Vector3.new(), Vector3.new(lv.X, 0, lv.Z))
		root.CFrame = CFrame.new(px, targetY, pz) * yaw
		activePlatform.CFrame = CFrame.new(px, savedFloor + currentHeight, pz)
	end)
end

local function startWalkMode(height)
	cleanUp()
	local character, root, humanoid, animator = getCharParts()
	if not root or not animator then return end

	currentHeight = height
	isWalkMode = true
	isActive = true

	activePlatform = makePlatform()

	local function getRayFloor()
		return getFloor(character, activePlatform)
	end

	local initFloor = getRayFloor()
	activePlatform.CFrame = CFrame.new(root.Position.X, initFloor + currentHeight, root.Position.Z)
	root.CFrame = CFrame.new(root.Position.X, initFloor + currentHeight + 3.5, root.Position.Z)

	activeTrack = loadAndPlayAnim(animator)

	walkConnection = RunService.Heartbeat:Connect(function()
		if not root or not root.Parent then cleanUp() return end

		local floorY = getRayFloor()
		local targetY = floorY + currentHeight + 3.5
		local newPos = Vector3.new(root.Position.X, root.Position.Y + (targetY - root.Position.Y) * 0.2, root.Position.Z)

		local moveDir = humanoid.MoveDirection
		local yaw
		if moveDir.Magnitude > 0.1 then
			yaw = CFrame.new(Vector3.new(), Vector3.new(moveDir.X, 0, moveDir.Z))
		else
			local lv = root.CFrame.LookVector
			yaw = CFrame.new(Vector3.new(), Vector3.new(lv.X, 0, lv.Z))
		end

		root.CFrame = CFrame.new(newPos) * yaw
		activePlatform.CFrame = CFrame.new(root.Position.X, floorY + currentHeight, root.Position.Z)
	end)
end

-- UI

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Flexing"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui") or player:WaitForChild("PlayerGui")

local TI = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function tween(obj, props)
	TweenService:Create(obj, TI, props):Play()
end

-- Pill button (shown when hidden)
local PillBtn = Instance.new("TextButton", ScreenGui)
PillBtn.Size = UDim2.new(0, 38, 0, 38)
PillBtn.Position = UDim2.new(0.5, -19, 0.35, 0)
PillBtn.BackgroundColor3 = Color3.fromRGB(55, 35, 120)
PillBtn.Text = "+"
PillBtn.TextColor3 = Color3.fromRGB(200, 175, 255)
PillBtn.Font = Enum.Font.GothamBold
PillBtn.TextSize = 22
PillBtn.BorderSizePixel = 0
PillBtn.Visible = false
PillBtn.Active = true
PillBtn.Draggable = true
Instance.new("UICorner", PillBtn).CornerRadius = UDim.new(0, 12)
local PillStroke = Instance.new("UIStroke", PillBtn)
PillStroke.Color = Color3.fromRGB(110, 75, 230)
PillStroke.Thickness = 1.5

-- Main frame
local FRAME_W = 220
local FRAME_H = 240
local TITLE_H = 42

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, FRAME_W, 0, FRAME_H)
MainFrame.Position = UDim2.new(0.5, -FRAME_W / 2, 0.35, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(11, 9, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true

local MCorner = Instance.new("UICorner", MainFrame)
MCorner.CornerRadius = UDim.new(0, 14)

local MStroke = Instance.new("UIStroke", MainFrame)
MStroke.Color = Color3.fromRGB(95, 60, 210)
MStroke.Thickness = 1.5

-- Title bar (rounded top only via separate frame)
local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
TitleBar.Position = UDim2.new(0, 0, 0, 0)
TitleBar.BackgroundColor3 = Color3.fromRGB(18, 13, 35)
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex = 2

-- UICorner on TitleBar would round all 4 corners, so we use a child frame to cover bottom corners
local TitleBarFill = Instance.new("Frame", TitleBar)
TitleBarFill.Size = UDim2.new(1, 0, 0.5, 0)
TitleBarFill.Position = UDim2.new(0, 0, 0.5, 0)
TitleBarFill.BackgroundColor3 = Color3.fromRGB(18, 13, 35)
TitleBarFill.BorderSizePixel = 0
TitleBarFill.ZIndex = 2

local TitleLabel = Instance.new("TextLabel", TitleBar)
TitleLabel.Size = UDim2.new(1, -100, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.Text = "FLEXING"
TitleLabel.TextColor3 = Color3.fromRGB(185, 155, 255)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 3

-- Title buttons — inside MainFrame, positioned absolutely so they stay inside
local function makeTitleBtn(txt, rightPad, bg)
	local b = Instance.new("TextButton", MainFrame)
	b.Size = UDim2.new(0, 26, 0, 26)
	b.Position = UDim2.new(1, -(rightPad + 26), 0, (TITLE_H - 26) / 2)
	b.Text = txt
	b.TextSize = 12
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = bg
	b.BorderSizePixel = 0
	b.ZIndex = 5
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
	return b
end

local CloseBtn = makeTitleBtn("X", 10, Color3.fromRGB(185, 38, 52))
local HideBtn  = makeTitleBtn("-", 42, Color3.fromRGB(42, 35, 78))

-- Hover animations on title buttons
for _, btn in ipairs({CloseBtn, HideBtn}) do
	local orig = btn.BackgroundColor3
	btn.MouseEnter:Connect(function()
		tween(btn, {BackgroundColor3 = orig:Lerp(Color3.new(1,1,1), 0.18)})
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, {BackgroundColor3 = orig})
	end)
end

-- Divider
local Divider = Instance.new("Frame", MainFrame)
Divider.Size = UDim2.new(1, -24, 0, 1)
Divider.Position = UDim2.new(0, 12, 0, TITLE_H)
Divider.BackgroundColor3 = Color3.fromRGB(95, 60, 210)
Divider.BackgroundTransparency = 0.55
Divider.BorderSizePixel = 0

-- Content
local Content = Instance.new("Frame", MainFrame)
Content.Size = UDim2.new(1, 0, 1, -TITLE_H - 1)
Content.Position = UDim2.new(0, 0, 0, TITLE_H + 1)
Content.BackgroundTransparency = 1

local PAD = 14

-- Height label
local HLabel = Instance.new("TextLabel", Content)
HLabel.Size = UDim2.new(1, -PAD*2, 0, 14)
HLabel.Position = UDim2.new(0, PAD, 0, 10)
HLabel.Text = "HEIGHT (STUDS)"
HLabel.TextColor3 = Color3.fromRGB(115, 95, 170)
HLabel.BackgroundTransparency = 1
HLabel.Font = Enum.Font.Gotham
HLabel.TextSize = 11
HLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Height input
local HeightInput = Instance.new("TextBox", Content)
HeightInput.Size = UDim2.new(1, -PAD*2, 0, 34)
HeightInput.Position = UDim2.new(0, PAD, 0, 26)
HeightInput.PlaceholderText = "Default: 15"
HeightInput.Text = ""
HeightInput.BackgroundColor3 = Color3.fromRGB(19, 15, 34)
HeightInput.TextColor3 = Color3.fromRGB(210, 195, 255)
HeightInput.PlaceholderColor3 = Color3.fromRGB(75, 60, 115)
HeightInput.Font = Enum.Font.GothamBold
HeightInput.TextSize = 13
HeightInput.BorderSizePixel = 0
HeightInput.ClearTextOnFocus = false
Instance.new("UICorner", HeightInput).CornerRadius = UDim.new(0, 9)
local HStroke = Instance.new("UIStroke", HeightInput)
HStroke.Color = Color3.fromRGB(95, 60, 210)
HStroke.Thickness = 1
HStroke.Transparency = 0.55

HeightInput.Focused:Connect(function()
	tween(HStroke, {Transparency = 0, Thickness = 1.5})
end)
HeightInput.FocusLost:Connect(function()
	tween(HStroke, {Transparency = 0.55, Thickness = 1})
end)

-- Buttons
local BW = math.floor((FRAME_W - PAD*2 - 8) / 2)

local function makeBtn(parent, txt, bg, xOff, yOff, w, h)
	local b = Instance.new("TextButton", parent)
	b.Size = UDim2.new(0, w, 0, h)
	b.Position = UDim2.new(0, xOff, 0, yOff)
	b.Text = txt
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = bg
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)

	local orig = bg
	local dim = bg:Lerp(Color3.new(0,0,0), 0.25)
	b.MouseEnter:Connect(function()
		tween(b, {BackgroundColor3 = bg:Lerp(Color3.new(1,1,1), 0.12)})
	end)
	b.MouseLeave:Connect(function()
		tween(b, {BackgroundColor3 = orig})
	end)
	b.MouseButton1Down:Connect(function()
		tween(b, {BackgroundColor3 = dim, Size = UDim2.new(0, w - 2, 0, h - 2), Position = UDim2.new(0, xOff + 1, 0, yOff + 1)})
	end)
	b.MouseButton1Up:Connect(function()
		tween(b, {BackgroundColor3 = orig, Size = UDim2.new(0, w, 0, h), Position = UDim2.new(0, xOff, 0, yOff)})
	end)

	return b
end

local StartBtn = makeBtn(Content, "START",     Color3.fromRGB(65, 32, 180), PAD,          74, BW, 34)
local StopBtn  = makeBtn(Content, "STOP",      Color3.fromRGB(165, 26, 52), PAD + BW + 8, 74, BW, 34)
local WalkBtn  = makeBtn(Content, "WALK MODE", Color3.fromRGB(22,  98, 170), PAD,         116, FRAME_W - PAD*2, 34)

-- Status row
local StatusDot = Instance.new("Frame", Content)
StatusDot.Size = UDim2.new(0, 7, 0, 7)
StatusDot.Position = UDim2.new(0, PAD, 0, 165)
StatusDot.BackgroundColor3 = Color3.fromRGB(75, 60, 125)
StatusDot.BorderSizePixel = 0
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(0.5, 0)

local StatusLabel = Instance.new("TextLabel", Content)
StatusLabel.Size = UDim2.new(1, -(PAD + 18), 0, 16)
StatusLabel.Position = UDim2.new(0, PAD + 13, 0, 161)
StatusLabel.Text = "Idle"
StatusLabel.TextColor3 = Color3.fromRGB(95, 80, 145)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left

local function setStatus(txt, dotClr, txtClr)
	StatusLabel.Text = txt
	tween(StatusLabel, {TextColor3 = txtClr or Color3.fromRGB(95, 80, 145)})
	tween(StatusDot,   {BackgroundColor3 = dotClr or Color3.fromRGB(75, 60, 125)})
end

-- Show/hide

local function showMain()
	MainFrame.Position = PillBtn.Position + UDim2.new(0, 19 - FRAME_W/2, 0, 0)
	MainFrame.Size = UDim2.new(0, FRAME_W, 0, 0)
	MainFrame.Visible = true
	PillBtn.Visible = false
	tween(MainFrame, {Size = UDim2.new(0, FRAME_W, 0, FRAME_H)})
end

local function hideMain()
	PillBtn.Position = MainFrame.Position + UDim2.new(0, FRAME_W/2 - 19, 0, 0)
	tween(MainFrame, {Size = UDim2.new(0, FRAME_W, 0, 0)})
	task.delay(0.2, function()
		MainFrame.Visible = false
		PillBtn.Visible = true
	end)
end

HideBtn.MouseButton1Click:Connect(hideMain)
PillBtn.MouseButton1Click:Connect(showMain)

CloseBtn.MouseButton1Click:Connect(function()
	cleanUp()
	tween(MainFrame, {Size = UDim2.new(0, FRAME_W, 0, 0)})
	task.delay(0.2, function() ScreenGui:Destroy() end)
end)

-- Logic

HeightInput:GetPropertyChangedSignal("Text"):Connect(function()
	local h = tonumber(HeightInput.Text)
	if h and h > 0 and isActive then
		currentHeight = h
		setStatus(
			(isWalkMode and "Walk: " or "Pose: ") .. h .. " studs",
			isWalkMode and Color3.fromRGB(35, 150, 220) or Color3.fromRGB(110, 75, 220),
			isWalkMode and Color3.fromRGB(80, 175, 255) or Color3.fromRGB(160, 130, 255)
		)
	end
end)

StartBtn.MouseButton1Click:Connect(function()
	local h = tonumber(HeightInput.Text) or DEFAULT_HEIGHT
	startPose(h)
	setStatus("Pose: " .. h .. " studs", Color3.fromRGB(110, 75, 220), Color3.fromRGB(160, 130, 255))
end)

StopBtn.MouseButton1Click:Connect(function()
	cleanUp()
	setStatus("Idle", Color3.fromRGB(75, 60, 125), Color3.fromRGB(95, 80, 145))
end)

WalkBtn.MouseButton1Click:Connect(function()
	local h = tonumber(HeightInput.Text) or DEFAULT_HEIGHT
	startWalkMode(h)
	setStatus("Walk: " .. h .. " studs", Color3.fromRGB(35, 150, 220), Color3.fromRGB(80, 175, 255))
end)
