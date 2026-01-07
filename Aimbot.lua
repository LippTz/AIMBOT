--====================================================
-- Krein Auto Lock v4.6 FINAL
-- Auto Lock Head + Team Check + Wall Check + ESP Highlight
--====================================================

--================ SERVICES ==========================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

--================ CONFIG ============================
local Config = {
	Aimbot = false,
	ESP = false,
	FOV = 200,
	ShowFOV = true,
	TeamCheck = true,
	WallCheck = true
}

--================ UTIL ==============================
local function IsAlive(plr)
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

local function IsEnemy(plr)
	if not Config.TeamCheck then return true end
	if not LocalPlayer.Team or not plr.Team then return true end
	return LocalPlayer.Team ~= plr.Team
end

local function GetHead(plr)
	return plr.Character and plr.Character:FindFirstChild("Head")
end

local function InFOV(pos)
	local s, v = Camera:WorldToViewportPoint(pos)
	if not v then return false end
	local center = Camera.ViewportSize / 2
	return (Vector2.new(s.X, s.Y) - center).Magnitude <= Config.FOV
end

--================ WALL CHECK ========================
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Blacklist
RayParams.IgnoreWater = true

local function HasLineOfSight(targetHead)
	if not Config.WallCheck then return true end

	local origin = Camera.CFrame.Position
	local direction = (targetHead.Position - origin)

	RayParams.FilterDescendantsInstances = {
		LocalPlayer.Character,
		targetHead.Parent
	}

	local result = workspace:Raycast(origin, direction, RayParams)

	-- Jika ray kena sesuatu SEBELUM head
	return (not result)
end

--================ AUTO LOCK =========================
local LockedHead = nil

local function AcquireTarget()
	local best, dist = nil, Config.FOV

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer
			and IsAlive(plr)
			and IsEnemy(plr) then

			local head = GetHead(plr)
			if head and InFOV(head.Position) and HasLineOfSight(head) then
				local s = Camera:WorldToViewportPoint(head.Position)
				local d = (Vector2.new(s.X, s.Y) - Camera.ViewportSize/2).Magnitude
				if d < dist then
					dist = d
					best = head
				end
			end
		end
	end

	return best
end

RunService.RenderStepped:Connect(function()
	if not Config.Aimbot then
		LockedHead = nil
		return
	end

	if not LockedHead
		or not LockedHead.Parent
		or not InFOV(LockedHead.Position)
		or not HasLineOfSight(LockedHead) then
		LockedHead = AcquireTarget()
	end

	if LockedHead then
		local camPos = Camera.CFrame.Position
		Camera.CFrame = CFrame.new(camPos, LockedHead.Position)
	end
end)

--================ ESP HIGHLIGHT =====================
local ESPObjects = {}

local function ApplyESP(plr)
	if plr == LocalPlayer then return end
	if not IsEnemy(plr) then return end
	if ESPObjects[plr] then return end

	local function onChar(char)
		if not Config.ESP then return end
		if not IsEnemy(plr) then return end

		local hl = Instance.new("Highlight")
		hl.Name = "KreinESP"
		hl.FillColor = Color3.fromRGB(255, 80, 80)
		hl.OutlineColor = Color3.fromRGB(255,255,255)
		hl.FillTransparency = 0.45
		hl.Adornee = char
		hl.Parent = char
		ESPObjects[plr] = hl
	end

	if plr.Character then
		onChar(plr.Character)
	end
	plr.CharacterAdded:Connect(onChar)
end

local function RemoveESP(plr)
	if ESPObjects[plr] then
		ESPObjects[plr]:Destroy()
		ESPObjects[plr] = nil
	end
end

Players.PlayerAdded:Connect(function(plr)
	ApplyESP(plr)
end)

Players.PlayerRemoving:Connect(RemoveESP)

local function RefreshESP()
	for _, plr in ipairs(Players:GetPlayers()) do
		if Config.ESP then
			ApplyESP(plr)
		else
			RemoveESP(plr)
		end
	end
end

--================ FOV CIRCLE ========================
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.Filled = false
FOVCircle.Color = Color3.fromRGB(255,255,255)

RunService.RenderStepped:Connect(function()
	FOVCircle.Visible = Config.ShowFOV
	FOVCircle.Radius = Config.FOV
	FOVCircle.Position = Camera.ViewportSize / 2
end)

--================ GUI ===============================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KreinAutoLockUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0,260,0,230)
Main.Position = UDim2.new(0.05,0,0.3,0)
Main.BackgroundColor3 = Color3.fromRGB(25,25,25)
Main.Active = true
Main.Draggable = true

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1,0,0,30)
Title.Text = "Krein Auto Lock v4.6"
Title.TextColor3 = Color3.new(1,1,1)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 18

local function Toggle(y, text, callback)
	local state = false
	local btn = Instance.new("TextButton", Main)
	btn.Size = UDim2.new(0,220,0,30)
	btn.Position = UDim2.new(0,20,0,y)
	btn.Text = text .. ": OFF"
	btn.BackgroundColor3 = Color3.fromRGB(160,60,60)
	btn.TextColor3 = Color3.new(1,1,1)

	btn.MouseButton1Click:Connect(function()
		state = not state
		btn.Text = text .. ": " .. (state and "ON" or "OFF")
		btn.BackgroundColor3 = state and Color3.fromRGB(60,160,60) or Color3.fromRGB(160,60,60)
		callback(state)
	end)
end

Toggle(40, "Auto Lock", function(v) Config.Aimbot = v end)
Toggle(80, "ESP Highlight", function(v) Config.ESP = v RefreshESP() end)
Toggle(120, "Show FOV", function(v) Config.ShowFOV = v end)
Toggle(160, "Team Check", function(v) Config.TeamCheck = v RefreshESP() end)
Toggle(200, "Wall Check", function(v) Config.WallCheck = v end)
