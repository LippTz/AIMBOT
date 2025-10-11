-- KreinAimbot v3 (Clean, readable)
-- Aimbot + ESP skeleton + FOV circle
-- Paste to Script Editor (executor) or LocalScript in StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera or workspace:WaitForChild("CurrentCamera")
local LocalPlayer = Players.LocalPlayer

local config = {
    Aimbot = false,
    ToggleMode = true,            -- true = toggle via GUI, false = hold-to-aim
    AimKey = Enum.UserInputType.MouseButton2,
    Smoothing = 0.18,             -- 0 = instant, larger = slower smoothing
    FOV = 160,                    -- pixels (screen radius)
    TargetPart = "Head",          -- Head / Body / UpperTorso / LowerTorso / HumanoidRootPart / Legs
    TeamCheck = true,
    ESP = false,
    ESPMaxDistance = 1000,
    ESPThickness = 1.4,
    ShowFOV = true,
    FOVThickness = 2,
}

-- ===== Utilities =====
local function safeIsAlive(player)
    if not player or not player.Character then return false end
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function findPart(character, names)
    if not character then return nil end
    for _, name in ipairs(names) do
        local p = character:FindFirstChild(name)
        if p and p:IsA("BasePart") then return p end
    end
    for _, c in ipairs(character:GetChildren()) do
        if c:IsA("BasePart") then return c end
    end
    return nil
end

local partLookup = {
    Head = {"Head"},
    Body = {"UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart"},
    UpperTorso = {"UpperTorso", "Torso", "HumanoidRootPart"},
    LowerTorso = {"LowerTorso", "HumanoidRootPart", "Torso"},
    HumanoidRootPart = {"HumanoidRootPart"},
    Legs = {"LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg","LowerTorso"},
}

local function getTargetPart(character, key)
    local names = partLookup[key] or {key}
    return findPart(character, names)
end

local function teamOf(player) return player and player.Team end

local function screenDistance(vec2)
    local cx, cy = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
    local dx, dy = vec2.X - cx, vec2.Y - cy
    return math.sqrt(dx * dx + dy * dy)
end

-- ===== Target selection =====
local function findClosestTarget()
    local best, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and safeIsAlive(p) then
            if (not config.TeamCheck) or (teamOf(p) ~= teamOf(LocalPlayer)) then
                local char = p.Character
                local part = getTargetPart(char, config.TargetPart)
                if part then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = screenDistance(Vector2.new(screenPos.X, screenPos.Y))
                        if dist <= config.FOV and dist < bestDist then
                            bestDist = dist
                            best = { player = p, part = part }
                        end
                    end
                end
            end
        end
    end
    return best
end

-- ===== Aiming =====
local function lerpCFrame(a, b, t)
    return a:Lerp(b, math.clamp(t, 0, 1))
end

local function aimAtPosition(position, dt)
    if not position then return end
    local camPos = Camera.CFrame.Position
    local desired = CFrame.new(camPos, position)
    local alpha
    if config.Smoothing <= 0 then
        alpha = 1
    else
        alpha = math.clamp(1 - math.exp(-(1 / config.Smoothing) * dt), 0, 1)
    end
    Camera.CFrame = lerpCFrame(Camera.CFrame, desired, alpha)
end

-- ===== Drawing / ESP =====
local DrawingObjects = {}
local bones = {
    {"Head","UpperTorso"},
    {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},
    {"UpperTorso","RightUpperArm"},
    {"LowerTorso","LeftUpperLeg"},
    {"LowerTorso","RightUpperLeg"},
    {"LeftUpperArm","LeftLowerArm"},
    {"RightUpperArm","RightLowerArm"},
    {"LeftUpperLeg","LeftLowerLeg"},
    {"RightUpperLeg","RightLowerLeg"},
}

local function createDrawingForPlayer(player)
    if DrawingObjects[player] then return end
    local data = { lines = {} }
    for i = 1, #bones do
        local ok, line = pcall(function() return Drawing.new("Line") end)
        if ok and line then
            line.Thickness = config.ESPThickness
            line.Transparency = 1
            line.Visible = false
            line.Color = Color3.fromRGB(255, 80, 80)
            data.lines[i] = line
        else
            data.lines[i] = nil
        end
    end
    DrawingObjects[player] = data
end

local function removeDrawingForPlayer(player)
    local data = DrawingObjects[player]
    if not data then return end
    for _, ln in ipairs(data.lines) do
        if ln then pcall(function() ln:Remove() end) end
    end
    DrawingObjects[player] = nil
end

Players.PlayerRemoving:Connect(function(p) removeDrawingForPlayer(p) end)

local function updateESP()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and safeIsAlive(p) and config.ESP then
            if not DrawingObjects[p] then createDrawingForPlayer(p) end
            local data = DrawingObjects[p]
            if not data then goto continue end

            local char = p.Character
            if not char then
                for _, ln in ipairs(data.lines) do if ln then ln.Visible = false end end
                goto continue
            end

            local hrp = char:FindFirstChild("HumanoidRootPart") or findPart(char, {"Torso","UpperTorso","LowerTorso"})
            if hrp and (hrp.Position - Camera.CFrame.Position).Magnitude > config.ESPMaxDistance then
                for _, ln in ipairs(data.lines) do if ln then ln.Visible = false end end
                goto continue
            end

            for i, b in ipairs(bones) do
                local aName, bName = b[1], b[2]
                local aPart = char:FindFirstChild(aName) or findPart(char, {aName})
                local bPart = char:FindFirstChild(bName) or findPart(char, {bName})
                local ln = data.lines[i]
                if aPart and bPart and ln then
                    local a2, on1 = Camera:WorldToViewportPoint(aPart.Position)
                    local b2, on2 = Camera:WorldToViewportPoint(bPart.Position)
                    if on1 and on2 then
                        ln.From = Vector2.new(a2.X, a2.Y)
                        ln.To = Vector2.new(b2.X, b2.Y)
                        ln.Visible = true
                    else
                        ln.Visible = false
                    end
                elseif ln then
                    ln.Visible = false
                end
            end
        else
            if DrawingObjects[p] then removeDrawingForPlayer(p) end
        end
        ::continue::
    end
end

-- ===== FOV circle =====
local fovCircle
do
    local ok, c = pcall(function() return Drawing.new("Circle") end)
    if ok and c then
        fovCircle = c
        fovCircle.Radius = config.FOV
        fovCircle.Visible = config.ShowFOV
        fovCircle.Filled = false
        fovCircle.Thickness = config.FOVThickness
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        fovCircle.Color = Color3.fromRGB(255, 255, 255)
    else
        fovCircle = nil
    end
end

-- ===== GUI =====
local function createGui()
    local sg = Instance.new("ScreenGui")
    sg.Name = "KreinAimbot_v3"
    sg.ResetOnSpawn = false
    sg.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local main = Instance.new("Frame", sg)
    main.Size = UDim2.new(0, 320, 0, 220)
    main.Position = UDim2.new(0, 20, 0, 120)
    main.BackgroundTransparency = 0.25
    main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    main.BorderSizePixel = 0

    local title = Instance.new("TextLabel", main)
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "KreinAimbot v3"
    title.TextScaled = true
    title.TextColor3 = Color3.fromRGB(255, 255, 255)

    local function makeToggle(y, text, initial, callback)
        local lbl = Instance.new("TextLabel", main)
        lbl.Size = UDim2.new(0, 170, 0, 24)
        lbl.Position = UDim2.new(0, 8, 0, y)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)

        local btn = Instance.new("TextButton", main)
        btn.Size = UDim2.new(0, 130, 0, 24)
        btn.Position = UDim2.new(0, 180, 0, y)
        btn.Text = initial and "ON" or "OFF"
        btn.BackgroundColor3 = initial and Color3.fromRGB(60, 160, 60) or Color3.fromRGB(160, 60, 60)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)

        btn.MouseButton1Click:Connect(function()
            initial = not initial
            btn.Text = initial and "ON" or "OFF"
            btn.BackgroundColor3 = initial and Color3.fromRGB(60, 160, 60) or Color3.fromRGB(160, 60, 60)
            callback(initial)
        end)

        return btn
    end

    makeToggle(40, "Aimbot", config.Aimbot, function(v) config.Aimbot = v end)
    makeToggle(70, "ESP Skeleton", config.ESP, function(v)
        config.ESP = v
        if not v then
            for pl, _ in pairs(DrawingObjects) do removeDrawingForPlayer(pl) end
        else
            for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then createDrawingForPlayer(p) end end
        end
    end)

    local parts = {"Head","UpperTorso","LowerTorso","HumanoidRootPart","Legs","Body"}
    local partLabel = Instance.new("TextLabel", main)
    partLabel.Size = UDim2.new(0, 170, 0, 22)
    partLabel.Position = UDim2.new(0, 8, 0, 108)
    partLabel.BackgroundTransparency = 1
    partLabel.Text = "Target: " .. config.TargetPart
    partLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    partLabel.TextXAlignment = Enum.TextXAlignment.Left

    local cycleBtn = Instance.new("TextButton", main)
    cycleBtn.Size = UDim2.new(0, 130, 0, 22)
    cycleBtn.Position = UDim2.new(0, 180, 0, 108)
    cycleBtn.Text = "Cycle Target"
    cycleBtn.MouseButton1Click:Connect(function()
        local idx = table.find(parts, config.TargetPart) or 1
        idx = idx + 1
        if idx > #parts then idx = 1 end
        config.TargetPart = parts[idx]
        partLabel.Text = "Target: " .. config.TargetPart
    end)

    local fovLabel = Instance.new("TextLabel", main)
    fovLabel.Size = UDim2.new(0, 170, 0, 22)
    fovLabel.Position = UDim2.new(0, 8, 0, 140)
    fovLabel.BackgroundTransparency = 1
    fovLabel.Text = ("FOV: %d px"):format(config.FOV)
    fovLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    fovLabel.TextXAlignment = Enum.TextXAlignment.Left

    local minusBtn = Instance.new("TextButton", main)
    minusBtn.Size = UDim2.new(0, 60, 0, 22)
    minusBtn.Position = UDim2.new(0, 180, 0, 140)
    minusBtn.Text = "-10"
    minusBtn.MouseButton1Click:Connect(function()
        config.FOV = math.clamp(config.FOV - 10, 20, 2000)
        fovLabel.Text = ("FOV: %d px"):format(config.FOV)
        if fovCircle then fovCircle.Radius = config.FOV end
    end)

    local plusBtn = Instance.new("TextButton", main)
    plusBtn.Size = UDim2.new(0, 60, 0, 22)
    plusBtn.Position = UDim2.new(0, 250, 0, 140)
    plusBtn.Text = "+10"
    plusBtn.MouseButton1Click:Connect(function()
        config.FOV = math.clamp(config.FOV + 10, 20, 2000)
        fovLabel.Text = ("FOV: %d px"):format(config.FOV)
        if fovCircle then fovCircle.Radius = config.FOV end
    end)

    makeToggle(172, "Show FOV", config.ShowFOV, function(v)
        config.ShowFOV = v
        if fovCircle then fovCircle.Visible = v end
    end)

    -- Dragging
    local dragging, dragStart, startPos
    main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    main.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    main.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ===== Initialization =====
createGui()
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then createDrawingForPlayer(p) end
end

-- ===== Input handling (hold-to-aim support) =====
local aimingHeld = false
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if not config.ToggleMode and input.UserInputType == config.AimKey then
        aimingHeld = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if not config.ToggleMode and input.UserInputType == config.AimKey then
        aimingHeld = false
    end
end)

-- ===== Main loop =====
RunService.RenderStepped:Connect(function(dt)
    pcall(updateESP)

    if fovCircle then
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        fovCircle.Radius = config.FOV
        fovCircle.Thickness = config.FOVThickness
        fovCircle.Visible = config.ShowFOV
    end

    local shouldAim = config.ToggleMode and config.Aimbot or (not config.ToggleMode and aimingHeld)
    if shouldAim then
        local target = findClosestTarget()
        if target and target.part then
            pcall(function() aimAtPosition(target.part.Position, dt) end)
        end
    end
end)

-- ===== Cleanup =====
game:BindToClose(function()
    for p, _ in pairs(DrawingObjects) do removeDrawingForPlayer(p) end
    if fovCircle then pcall(function() fovCircle:Remove() end) end
end)
