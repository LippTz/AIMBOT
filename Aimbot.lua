-- Krein Aimbot v4 - Clean Rebuild
-- Fitur: Aimbot Toggle, Target Part Switch, ESP Skeleton, FOV Circle

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Config
local Config = {
    Aimbot = false,
    ESP = false,
    TargetPart = "Head",
    FOV = 150,
    ShowFOV = true,
    Smoothing = 0.2,
}

-- ====== UTILITY FUNCTIONS ======
local function IsAlive(player)
    return player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0
end

local function GetTargetPart(char)
    if Config.TargetPart == "Head" then
        return char:FindFirstChild("Head")
    elseif Config.TargetPart == "Body" then
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    elseif Config.TargetPart == "Leg" then
        return char:FindFirstChild("RightFoot") or char:FindFirstChild("LeftFoot")
    end
    return nil
end

local function GetClosestPlayer()
    local Closest = nil
    local Shortest = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            local part = GetTargetPart(player.Character)
            if part then
                local screenPos, visible = Camera:WorldToViewportPoint(part.Position)
                if visible then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                    if dist < Config.FOV and dist < Shortest then
                        Shortest = dist
                        Closest = part
                    end
                end
            end
        end
    end

    return Closest
end

-- ====== AIMBOT ======
RunService.RenderStepped:Connect(function(dt)
    if Config.Aimbot then
        local target = GetClosestPlayer()
        if target then
            local direction = (target.Position - Camera.CFrame.Position).Unit
            local targetCFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + direction)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Config.Smoothing)
        end
    end
end)

-- ====== ESP SKELETON ======
local Skeletons = {}
local Bones = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"UpperTorso", "RightUpperArm"},
    {"LowerTorso", "LeftUpperLeg"}, {"LowerTorso", "RightUpperLeg"},
    {"LeftUpperArm", "LeftLowerArm"}, {"RightUpperArm", "RightLowerArm"},
    {"LeftUpperLeg", "LeftLowerLeg"}, {"RightUpperLeg", "RightLowerLeg"}
}

local function CreateSkeleton(player)
    if Skeletons[player] then return end
    Skeletons[player] = {}
    for _, bone in ipairs(Bones) do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = Color3.fromRGB(255, 60, 60)
        line.Thickness = 1.5
        table.insert(Skeletons[player], {bone = bone, line = line})
    end
end

local function ClearSkeleton(player)
    if Skeletons[player] then
        for _, obj in ipairs(Skeletons[player]) do
            obj.line:Remove()
        end
        Skeletons[player] = nil
    end
end

Players.PlayerRemoving:Connect(ClearSkeleton)

RunService.RenderStepped:Connect(function()
    if not Config.ESP then
        for _, lines in pairs(Skeletons) do
            for _, obj in ipairs(lines) do
                obj.line.Visible = false
            end
        end
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            if not Skeletons[player] then CreateSkeleton(player) end
            local char = player.Character
            for _, obj in ipairs(Skeletons[player]) do
                local a = char:FindFirstChild(obj.bone[1])
                local b = char:FindFirstChild(obj.bone[2])
                if a and b then
                    local aPos, aVis = Camera:WorldToViewportPoint(a.Position)
                    local bPos, bVis = Camera:WorldToViewportPoint(b.Position)
                    if aVis and bVis then
                        obj.line.From = Vector2.new(aPos.X, aPos.Y)
                        obj.line.To = Vector2.new(bPos.X, bPos.Y)
                        obj.line.Visible = true
                    else
                        obj.line.Visible = false
                    end
                else
                    obj.line.Visible = false
                end
            end
        end
    end
end)

-- ====== FOV CIRCLE ======
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = true
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Thickness = 2
FOVCircle.Filled = false
RunService.RenderStepped:Connect(function()
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    FOVCircle.Radius = Config.FOV
    FOVCircle.Visible = Config.ShowFOV
end)

-- ====== GUI ======
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.Name = "KreinAimbotUI"

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 250, 0, 210)
Main.Position = UDim2.new(0.05, 0, 0.3, 0)
Main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundTransparency = 1
Title.Text = "Krein Aimbot v4"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 18

-- BUTTON FUNCTION
local function CreateToggle(y, text, default, callback)
    local Label = Instance.new("TextLabel", Main)
    Label.Size = UDim2.new(0, 140, 0, 25)
    Label.Position = UDim2.new(0, 10, 0, y)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.TextXAlignment = Enum.TextXAlignment.Left

    local Btn = Instance.new("TextButton", Main)
    Btn.Size = UDim2.new(0, 80, 0, 25)
    Btn.Position = UDim2.new(0, 160, 0, y)
    Btn.Text = default and "ON" or "OFF"
    Btn.BackgroundColor3 = default and Color3.fromRGB(60, 160, 60) or Color3.fromRGB(160, 60, 60)
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)

    Btn.MouseButton1Click:Connect(function()
        default = not default
        Btn.Text = default and "ON" or "OFF"
        Btn.BackgroundColor3 = default and Color3.fromRGB(60, 160, 60) or Color3.fromRGB(160, 60, 60)
        callback(default)
    end)
end

-- TOGGLES
CreateToggle(40, "Aimbot", false, function(v) Config.Aimbot = v end)
CreateToggle(70, "ESP Skeleton", false, function(v) Config.ESP = v end)
CreateToggle(100, "Show FOV", true, function(v) Config.ShowFOV = v end)

-- TARGET PART SWITCH
local TargetLabel = Instance.new("TextLabel", Main)
TargetLabel.Size = UDim2.new(0, 140, 0, 25)
TargetLabel.Position = UDim2.new(0, 10, 0, 130)
TargetLabel.BackgroundTransparency = 1
TargetLabel.Text = "Target: " .. Config.TargetPart
TargetLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TargetLabel.TextXAlignment = Enum.TextXAlignment.Left

local ChangeBtn = Instance.new("TextButton", Main)
ChangeBtn.Size = UDim2.new(0, 80, 0, 25)
ChangeBtn.Position = UDim2.new(0, 160, 0, 130)
ChangeBtn.Text = "Change"
ChangeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 150)
ChangeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)

ChangeBtn.MouseButton1Click:Connect(function()
    local order = {"Head", "Body", "Leg"}
    local index = table.find(order, Config.TargetPart) or 1
    index = (index % #order) + 1
    Config.TargetPart = order[index]
    TargetLabel.Text = "Target: " .. Config.TargetPart
end)

-- FOV ADJUST
local FOVLabel = Instance.new("TextLabel", Main)
FOVLabel.Size = UDim2.new(0, 140, 0, 25)
FOVLabel.Position = UDim2.new(0, 10, 0, 160)
FOVLabel.BackgroundTransparency = 1
FOVLabel.Text = "FOV: " .. Config.FOV
FOVLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
FOVLabel.TextXAlignment = Enum.TextXAlignment.Left

local MinusBtn = Instance.new("TextButton", Main)
MinusBtn.Size = UDim2.new(0, 35, 0, 25)
MinusBtn.Position = UDim2.new(0, 160, 0, 160)
MinusBtn.Text = "-"
MinusBtn.MouseButton1Click:Connect(function()
    Config.FOV = math.clamp(Config.FOV - 10, 20, 400)
    FOVLabel.Text = "FOV: " .. Config.FOV
end)

local PlusBtn = Instance.new("TextButton", Main)
PlusBtn.Size = UDim2.new(0, 35, 0, 25)
PlusBtn.Position = UDim2.new(0, 205, 0, 160)
PlusBtn.Text = "+"
PlusBtn.MouseButton1Click:Connect(function()
    Config.FOV = math.clamp(Config.FOV + 10, 20, 400)
    FOVLabel.Text = "FOV: " .. Config.FOV
end)
