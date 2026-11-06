--[[
    Pulsar.One - Kukirin Life toolkit
      - Auto Wheelie   (locks chassis pitch, optional freeze)
      - Auto Tricks    (backflip / frontflip / 180 / 360 spin farm)
      - Police Push    (launches PoliceNPCs away + blocks PoliceHit + auto get-up)
      - Police ESP     (highlight + POLICE tag)
      - Claim Rewards  (daily / quest / achievement)
      - Speed Boost    (character + ride)
      - Speed Uncap    (higher walk + ride velocity)
      - Desync         (CameraModule sees a rotated root)
      - CFrame Fly     (camera-relative CFrame vfly)

    F6 hides the panel.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait(0.1); LocalPlayer = Players.LocalPlayer end
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local remotes = RS:FindFirstChild("Remotes")
local charRemotes = remotes and remotes:FindFirstChild("Character")
local function remote(path)
    local cur = remotes
    for _, seg in ipairs(path) do
        if not cur then return nil end
        cur = cur:FindFirstChild(seg)
    end
    return cur
end

local WheelieState = charRemotes and charRemotes:FindFirstChild("WheelieState")
local PoliceHit = charRemotes and charRemotes:FindFirstChild("PoliceHit")
local TrickState = remote({ "Tricks", "TrickState" })
local claimDaily = remote({ "DailyRewards", "ClaimDailyReward" })
local claimQuest = remote({ "Quests", "ClaimQuest" })
local claimAch = remote({ "Achievements", "ClaimAchievementReward" })

local state = {
    wheelie = false,
    antiPolice = false,
    policeEsp = false,
    tricks = false,
    claims = false,
    freeze = false,
    speed = false,
    uncap = false,
    desync = false,
    fly = false,
    angle = 55,
    rideSpeed = 120,
    flySpeed = 80,
    ride = nil,
    pushed = 0,
    claimed = 0,
    trickCash = 0,
    lastTrick = nil,
}

-- ============================================================
-- UI
-- ============================================================
local old = playerGui:FindFirstChild("PulsarKukirin")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "PulsarKukirin"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(320, 480)
frame.Position = UDim2.fromOffset(20, 140)
frame.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui

local corner1 = Instance.new("UICorner")
corner1.CornerRadius = UDim.new(0, 8)
corner1.Parent = frame

local stroke1 = Instance.new("UIStroke")
stroke1.Color = Color3.fromRGB(56, 124, 255)
stroke1.Thickness = 1
stroke1.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 26)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextColor3 = Color3.fromRGB(232, 238, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "  Pulsar.One | Kukirin Life"
title.Active = true
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 30)
status.Position = UDim2.fromOffset(8, 28)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 10
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(150, 160, 180)
status.Text = "loading..."
status.Parent = frame

local function mkToggle(label, y, flag)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -16, 0, 24)
    b.Position = UDim2.fromOffset(8, y)
    b.BackgroundColor3 = Color3.fromRGB(28, 38, 56)
    b.BorderSizePixel = 0
    b.Font = Enum.Font.Gotham
    b.TextSize = 11
    b.TextColor3 = Color3.fromRGB(220, 228, 240)
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Text = "  " .. label .. ": off"
    b.Parent = frame
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = b
    b.MouseButton1Click:Connect(function()
        state[flag] = not state[flag]
        b.Text = "  " .. label .. ": " .. (state[flag] and "on" or "off")
        b.BackgroundColor3 = state[flag] and Color3.fromRGB(40, 80, 150) or Color3.fromRGB(28, 38, 56)
    end)
end

local function mkSlider(label, y, flag, minimum, maximum, value, suffix)
    local lab = Instance.new("TextLabel")
    lab.Size = UDim2.new(1, -16, 0, 16)
    lab.Position = UDim2.fromOffset(8, y)
    lab.BackgroundTransparency = 1
    lab.Font = Enum.Font.Gotham
    lab.TextSize = 10
    lab.TextXAlignment = Enum.TextXAlignment.Left
    lab.TextColor3 = Color3.fromRGB(170, 180, 200)
    lab.Parent = frame

    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(1, -16, 0, 10)
    bar.Position = UDim2.fromOffset(8, y + 18)
    bar.BackgroundColor3 = Color3.fromRGB(28, 38, 56)
    bar.BorderSizePixel = 0
    bar.Text = ""
    bar.Parent = frame
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 4)
    bc.Parent = bar

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0.5, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(56, 124, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(0, 4)
    fc.Parent = fill

    local function setValue(v)
        state[flag] = v
        fill.Size = UDim2.new((v - minimum) / (maximum - minimum), 0, 1, 0)
        lab.Text = string.format("%s: %.0f%s", label, v, suffix or "")
    end

    local function seek()
        local m = UIS:GetMouseLocation()
        local rel = math.clamp((m.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        setValue(minimum + rel * (maximum - minimum))
    end

    setValue(value)
    bar.MouseButton1Click:Connect(seek)
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            seek()
        end
    end)
end

mkToggle("auto wheelie", 62, "wheelie")
mkToggle("police push", 88, "antiPolice")
mkToggle("police esp", 114, "policeEsp")
mkToggle("auto tricks", 140, "tricks")
mkToggle("auto claim", 166, "claims")
mkToggle("freeze position", 192, "freeze")
mkToggle("speed boost", 218, "speed")
mkToggle("speed uncap", 244, "uncap")
mkToggle("desync", 270, "desync")
mkToggle("cframe fly", 296, "fly")

mkSlider("wheelie angle", 326, "angle", -80, 80, 55, " deg")
mkSlider("ride speed", 362, "rideSpeed", 30, 300, 120, " studs/s")
mkSlider("fly speed", 398, "flySpeed", 10, 500, 80, " studs/s")

local restore = Instance.new("TextButton")
restore.Size = UDim2.new(1, -16, 0, 24)
restore.Position = UDim2.fromOffset(8, 442)
restore.BackgroundColor3 = Color3.fromRGB(28, 38, 56)
restore.BorderSizePixel = 0
restore.Font = Enum.Font.Gotham
restore.TextSize = 11
restore.TextColor3 = Color3.fromRGB(220, 228, 240)
restore.Text = "restore hooks / fly"
restore.Parent = frame
local rc = Instance.new("UICorner")
rc.CornerRadius = UDim.new(0, 4)
rc.Parent = restore

-- draggable
local dragging, dragStart, startPos = false, nil, nil
title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local function refreshStatus()
    status.Text = string.format(
        "ride: %s | last: %s\ncash: $%d | pushed: %d | claimed: %d",
        state.ride and state.ride.Name or "none",
        state.lastTrick or "none",
        state.trickCash, state.pushed, state.claimed
    )
end

-- ============================================================
-- HELPERS
-- ============================================================
local function currentRide()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local seat = hum and hum.SeatPart
    if not seat then return nil end
    local rides = workspace:FindFirstChild("Rides")
    if not rides then return nil end
    for _, model in ipairs(rides:GetChildren()) do
        if seat:IsDescendantOf(model) then return model end
    end
    return nil
end

local function findChassis(model)
    local seat = model:FindFirstChild("DriveSeat")
    if seat and seat:IsA("BasePart") then return seat end
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

-- ============================================================
-- AUTO WHEELIE + ASSIST PARKING
-- ============================================================
local wheelieActive = false
local wheelieChassis = nil
local disabledAssists = {}
local parkedRide = nil

local function restoreAssists()
    for inst in pairs(disabledAssists) do
        if inst.Parent then
            pcall(function() inst.Enabled = true end)
        end
    end
    table.clear(disabledAssists)
    parkedRide = nil
end

local function parkAssists(model)
    if parkedRide ~= model then
        restoreAssists()
        parkedRide = model
        for _, d in ipairs(model:GetDescendants()) do
            if (d.Name == "Flip" or d.Name == "Kickstand") and (d:IsA("AlignOrientation") or d:IsA("BodyGyro")) then
                disabledAssists[d] = true
            end
        end
    end

    for inst in pairs(disabledAssists) do
        if inst.Parent and inst.Enabled then
            pcall(function() inst.Enabled = false end)
        end
    end
end

local function lockWheelie(model)
    local chassis = findChassis(model)
    if not chassis then return end
    wheelieChassis = chassis

    if state.freeze then
        local _, yaw, _ = chassis.CFrame:ToOrientation()
        chassis.CFrame = CFrame.new(chassis.Position) * CFrame.Angles(math.rad(state.angle), yaw, 0)
        chassis.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        chassis.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        chassis.Anchored = true
        return
    end

    if chassis.Anchored then
        chassis.Anchored = false
    end

    local pitch = math.asin(math.clamp(chassis.CFrame.LookVector.Y, -1, 1))
    local target = math.rad(state.angle)
    local err = target - pitch
    local power = math.clamp(err * 14, -22, 22)

    local right = chassis.CFrame.RightVector
    local up = chassis.CFrame.UpVector
    local look = chassis.CFrame.LookVector
    local av = chassis.AssemblyAngularVelocity

    chassis.AssemblyAngularVelocity = right * power + up * av:Dot(up) + look * av:Dot(look)
end

local function unlockWheelie()
    if wheelieChassis then
        pcall(function()
            wheelieChassis.Anchored = false
            wheelieChassis.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end)
        wheelieChassis = nil
    end
    if WheelieState then
        pcall(function() WheelieState:FireServer(false) end)
    end
end

local function getTrickInput()
    local aChassis = playerGui:FindFirstChild("A-Chassis Interface")
    local riderPhysics = aChassis and aChassis:FindFirstChild("RiderPhysics")
    return riderPhysics and riderPhysics:FindFirstChild("TrickInput")
end

-- ============================================================
-- AUTO TRICKS (backflip / frontflip / 180 / 360)
-- ============================================================
local trick = {
    active = false,
    mode = nil,
    axis = Vector3.new(0, 0, 0),
    rate = 0,
    endsAt = 0,
    nextAt = 0,
    hopAt = nil,
}

local function isGrounded(ride, chassis)
    local filter = { ride }
    if LocalPlayer.Character then
        table.insert(filter, LocalPlayer.Character)
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = filter
    local hit = workspace:Raycast(chassis.Position, Vector3.new(0, -7, 0), params)
    return hit ~= nil
end

local function startTrick(ride, chassis)
    if trick.active then return end

    if wheelieActive then
        wheelieActive = false
        unlockWheelie()
    end

    local roll = math.random()
    local mode, rate, duration
    if roll < 0.40 then
        mode, rate, duration = "Backflip", 12, 0.58
    elseif roll < 0.60 then
        mode, rate, duration = "Frontflip", -12, 0.58
    elseif roll < 0.85 then
        mode, rate, duration = "360 Spin", 11, 0.60
    else
        mode, rate, duration = "180 Spin", 10, 0.34
    end

    trick.active = true
    trick.mode = mode
    trick.rate = rate
    trick.endsAt = os.clock() + duration

    if mode == "Backflip" or mode == "Frontflip" then
        trick.axis = chassis.CFrame.RightVector
    else
        trick.axis = chassis.CFrame.UpVector
    end

    local ti = getTrickInput()
    if ti then
        pcall(function() ti:Fire(mode, true) end)
    end
end

local function stopTrick()
    trick.active = false
    trick.mode = nil
    trick.hopAt = nil
    trick.nextAt = os.clock() + 2.2

    local ride = state.ride
    if ride then
        local chassis = findChassis(ride)
        if chassis then
            chassis.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end
end

local function updateTricks(ride)
    if not state.tricks or not ride or state.fly then return end
    local chassis = findChassis(ride)
    if not chassis then return end

    local now = os.clock()

    if trick.active then
        if now < trick.endsAt then
            chassis.AssemblyAngularVelocity = trick.axis * trick.rate
        else
            stopTrick()
        end
        return
    end

    if trick.hopAt then
        if now >= trick.hopAt then
            trick.hopAt = nil
            if not isGrounded(ride, chassis) then
                startTrick(ride, chassis)
            else
                trick.nextAt = now + 0.6
            end
        end
        return
    end

    if now < trick.nextAt then return end

    if not isGrounded(ride, chassis) then
        startTrick(ride, chassis)
        return
    end

    if UIS:IsKeyDown(Enum.KeyCode.W) then
        local v = chassis.AssemblyLinearVelocity
        local flat = Vector3.new(v.X, 0, v.Z)
        if flat.Magnitude > 8 then
            chassis.AssemblyLinearVelocity = Vector3.new(v.X, 72, v.Z)
            trick.hopAt = now + 0.16
        end
    end
end

if TrickState then
    TrickState.OnClientEvent:Connect(function(kind, name, amount)
        if kind == "landed" then
            if name then state.lastTrick = name end
            if type(amount) == "number" and amount > 0 then
                state.trickCash = state.trickCash + amount
            end
        elseif kind == "air" or kind == "landing" then
            if name then state.lastTrick = name end
        end
    end)
end

-- ============================================================
-- POLICE PUSH + ESP
-- ============================================================
local ragdoll
pcall(function()
    ragdoll = require(RS:WaitForChild("Modules"):WaitForChild("Main"):WaitForChild("RagdollCollision"))
end)

local policeModels, policeScanAt, policeStuck = {}, 0, {}
local lastPush = 0

local function refreshPolice()
    policeModels = {}
    local folder = workspace:FindFirstChild("PoliceNPCs")
    if not folder then return end
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("Model") then
            policeModels[#policeModels + 1] = obj
        end
    end
end

local function pushPolice()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if os.clock() - policeScanAt > 2 then
        policeScanAt = os.clock()
        refreshPolice()
    end

    local playerPos = root.Position
    for _, model in ipairs(policeModels) do
        if model.Parent then
            local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            if primary then
                local delta = primary.Position - playerPos
                local flat = Vector3.new(delta.X, 0, delta.Z)
                local dist = flat.Magnitude

                if dist < 180 then
                    policeStuck[model] = (policeStuck[model] or 0) + 1
                    if policeStuck[model] >= 8 then
                        pcall(function() model.Parent = nil end)
                        policeStuck[model] = nil
                    end
                else
                    policeStuck[model] = 0
                end

                if dist < 450 then
                    local dir
                    if dist > 0.5 then
                        dir = flat.Unit
                    else
                        local a = math.random() * math.pi * 2
                        dir = Vector3.new(math.cos(a), 0, math.sin(a))
                    end

                    local pivot = model:GetPivot()
                    local rot = pivot - pivot.Position
                    local target = playerPos + dir * 520 + Vector3.new(0, 200, 0)
                    pcall(function() model:PivotTo(CFrame.new(target) * rot) end)

                    for _, p in ipairs(model:GetDescendants()) do
                        if p:IsA("BasePart") then
                            p.CanCollide = false
                            p.CanTouch = false
                            p.Massless = true
                            p.AssemblyLinearVelocity = dir * 350 + Vector3.new(0, 120, 0)
                        end
                    end

                    state.pushed = state.pushed + 1
                end
            end
        end
    end
end

local policeHighlights, policeTags = {}, {}

local function clearPoliceEsp()
    for model, h in pairs(policeHighlights) do
        pcall(function() h:Destroy() end)
        policeHighlights[model] = nil
    end
    for model, t in pairs(policeTags) do
        pcall(function() t:Destroy() end)
        policeTags[model] = nil
    end
end

local function updatePoliceEsp()
    if not state.policeEsp then
        clearPoliceEsp()
        return
    end

    local folder = workspace:FindFirstChild("PoliceNPCs")
    if not folder then
        clearPoliceEsp()
        return
    end

    local live = {}
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") then
            live[model] = true

            local h = policeHighlights[model]
            if not h or not h.Parent then
                h = Instance.new("Highlight")
                h.Name = "PulsarPoliceESP"
                h.Adornee = model
                h.FillColor = Color3.fromRGB(255, 45, 45)
                h.OutlineColor = Color3.fromRGB(255, 255, 255)
                h.FillTransparency = 0.55
                h.OutlineTransparency = 0
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.Parent = model
                policeHighlights[model] = h
            end

            local tag = policeTags[model]
            if not tag or not tag.Parent then
                tag = Instance.new("BillboardGui")
                tag.Name = "PulsarPoliceTag"
                tag.Size = UDim2.fromOffset(90, 22)
                tag.StudsOffset = Vector3.new(0, 7, 0)
                tag.AlwaysOnTop = true
                tag.Adornee = model
                tag.Parent = model

                local label = Instance.new("TextLabel")
                label.Size = UDim2.fromScale(1, 1)
                label.BackgroundTransparency = 1
                label.Font = Enum.Font.GothamBold
                label.TextSize = 12
                label.TextColor3 = Color3.fromRGB(255, 70, 70)
                label.TextStrokeTransparency = 0
                label.Text = "POLICE"
                label.Parent = tag

                policeTags[model] = tag
            end
        end
    end

    for model, h in pairs(policeHighlights) do
        if not live[model] then
            pcall(function() h:Destroy() end)
            policeHighlights[model] = nil
        end
    end
    for model, t in pairs(policeTags) do
        if not live[model] then
            pcall(function() t:Destroy() end)
            policeTags[model] = nil
        end
    end
end

-- ============================================================
-- ANTI-POLICE HOOK
-- ============================================================
local hookMt, hookOld, hookOn = nil, nil, false

local function installHook()
    if hookOn or not PoliceHit then return end
    if not (getrawmetatable and newcclosure and getnamecallmethod) then return end
    pcall(function()
        local mt = getrawmetatable(game)
        hookMt, hookOld = mt, mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            if self == PoliceHit and getnamecallmethod() == "FireServer" then
                return
            end
            return hookOld(self, ...)
        end)
        setreadonly(mt, true)
        hookOn = true
    end)
end

local function removeHook()
    if not hookOn then return end
    pcall(function()
        setreadonly(hookMt, false)
        rawset(hookMt, "__namecall", hookOld)
        setreadonly(hookMt, true)
    end)
    hookOn = false
end

-- ============================================================
-- SPEED
-- ============================================================
local baseWalkSpeed = nil

local function applySpeed()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if baseWalkSpeed == nil then
        baseWalkSpeed = hum.WalkSpeed > 0 and hum.WalkSpeed or 16
    end

    if not state.fly and not hum.SeatPart then
        if state.uncap then
            hum.WalkSpeed = 300
        elseif state.speed then
            hum.WalkSpeed = 60
        else
            hum.WalkSpeed = baseWalkSpeed
        end
    end

    if (state.speed or state.uncap) and hum.SeatPart and not state.fly then
        local ride = currentRide()
        if ride then
            local chassis = findChassis(ride)
            if chassis then
                local v = chassis.AssemblyLinearVelocity
                local look = chassis.CFrame.LookVector
                local flat = Vector3.new(look.X, 0, look.Z)
                if flat.Magnitude > 0.1 and UIS:IsKeyDown(Enum.KeyCode.W) then
                    local target = state.uncap and math.min(state.rideSpeed * 4, 2000) or state.rideSpeed
                    chassis.AssemblyLinearVelocity = flat.Unit * target + Vector3.new(0, v.Y, 0)
                end
            end
        end
    end
end

-- ============================================================
-- CFLY (CFRAME FLY)
-- ============================================================
local flyPos, flyHum = nil, nil
local flySavedParts = {}

local function startFly()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    if hum.SeatPart then
        pcall(function() hum.Sit = false end)
    end

    flyHum = hum
    flyPos = root.CFrame

    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            flySavedParts[p] = p.CanCollide
            p.CanCollide = false
        end
    end

    hum.PlatformStand = true
end

local function stopFly()
    if flyHum then
        pcall(function() flyHum.PlatformStand = false end)
    end
    for p, collide in pairs(flySavedParts) do
        if p.Parent then
            pcall(function() p.CanCollide = collide end)
        end
    end
    table.clear(flySavedParts)
    flyPos, flyHum = nil, nil
end

local function updateFly(dt)
    if not state.fly then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    if not flyPos then
        startFly()
        if not flyPos then return end
    end

    local cam = workspace.CurrentCamera
    local look = cam.CFrame.LookVector
    local right = cam.CFrame.RightVector
    local move = Vector3.new(0, 0, 0)

    if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + look end
    if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - look end
    if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + right end
    if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - right end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end

    if move.Magnitude > 0 then
        flyPos = flyPos + move.Unit * state.flySpeed * dt
    end

    local flat = Vector3.new(look.X, 0, look.Z)
    local yaw = 0
    if flat.Magnitude > 0.01 then
        yaw = math.atan2(-flat.X, -flat.Z)
    end

    root.CFrame = CFrame.new(flyPos.Position) * CFrame.Angles(0, yaw, 0)
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    hum.PlatformStand = true
end

-- ============================================================
-- DESYNC
-- ============================================================
local desyncState = nil

local function applyDesync()
    if desyncState then return end
    pcall(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root or not getrawmetatable then return end

        local mt = getrawmetatable(root)
        local oldIndex = mt.__index
        setreadonly(mt, false)
        mt.__index = newcclosure(function(self, key)
            local value = oldIndex(self, key)
            if key == "CFrame" and not checkcaller() then
                local ok, name = pcall(function()
                    local sc = getcallingscript and getcallingscript()
                    return sc and sc.Name
                end)
                if ok and name == "CameraModule" then
                    return value * CFrame.Angles(0, math.rad(90), 0)
                end
            end
            return value
        end)
        setreadonly(mt, true)
        desyncState = { mt = mt, oldIndex = oldIndex }
    end)
end

local function removeDesync()
    if not desyncState then return end
    pcall(function()
        setreadonly(desyncState.mt, false)
        rawset(desyncState.mt, "__index", desyncState.oldIndex)
        setreadonly(desyncState.mt, true)
    end)
    desyncState = nil
end

-- ============================================================
-- CLAIMS
-- ============================================================
local function claimRewards()
    for _, r in ipairs({ claimDaily, claimQuest, claimAch }) do
        if r then
            pcall(function()
                local ok = r:InvokeServer()
                if ok ~= nil then state.claimed = state.claimed + 1 end
            end)
        end
    end
end

-- ============================================================
-- LOOPS
-- ============================================================
local lastEsp, lastClaim, lastStatus = 0, 0, 0

RunService.Heartbeat:Connect(function()
    pcall(function()
        local ride = currentRide()
        state.ride = ride

        if state.tricks and ride then
            updateTricks(ride)
        end

        local needPark = (state.wheelie and ride) or (state.tricks and trick.active)
        if needPark and ride then
            parkAssists(ride)
        else
            restoreAssists()
        end

        if state.wheelie and ride and not (state.tricks and trick.active) then
            if not wheelieActive then
                wheelieActive = true
                local ti = getTrickInput()
                if ti then pcall(function() ti:Fire("Wheelie", true) end) end
                if WheelieState then pcall(function() WheelieState:FireServer(true) end) end
            end
            lockWheelie(ride)
        elseif wheelieActive then
            wheelieActive = false
            unlockWheelie()
            local ti = getTrickInput()
            if ti then pcall(function() ti:Fire("Wheelie", false) end) end
        end

        if state.antiPolice then
            if not hookOn then installHook() end
            if os.clock() - lastPush > 0.08 then
                lastPush = os.clock()
                pushPolice()
            end
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum:GetState() == Enum.HumanoidStateType.Physics and not hum.SeatPart then
                if ragdoll then pcall(function() ragdoll.release() end) end
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            end
        end

        if os.clock() - lastEsp > 1 then
            lastEsp = os.clock()
            updatePoliceEsp()
        end

        if state.claims and os.clock() - lastClaim > 5 then
            lastClaim = os.clock()
            claimRewards()
        end

        applySpeed()

        if state.desync then
            if not desyncState then applyDesync() end
        elseif desyncState then
            removeDesync()
        end

        if state.fly then
            if not flyPos then startFly() end
        elseif flyPos then
            stopFly()
        end

        if os.clock() - lastStatus > 0.25 then
            lastStatus = os.clock()
            refreshStatus()
        end
    end)
end)

RunService.RenderStepped:Connect(function(dt)
    if state.fly then pcall(updateFly, dt) end
end)

restore.MouseButton1Click:Connect(function()
    removeHook()
    removeDesync()
    if flyPos then stopFly() end
    if wheelieActive then
        wheelieActive = false
        unlockWheelie()
    end
    if trick.active then stopTrick() end
    restoreAssists()
    for k in pairs(state) do
        if type(state[k]) == "boolean" then state[k] = false end
    end
    for _, b in ipairs(frame:GetChildren()) do
        if b:IsA("TextButton") and b.Text:find(":") then
            b.Text = b.Text:gsub(": on", ": off")
            b.BackgroundColor3 = Color3.fromRGB(28, 38, 56)
        end
    end
end)

UIS.InputBegan:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.F6 then
        frame.Visible = not frame.Visible
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    flyPos, flyHum = nil, nil
    table.clear(flySavedParts)
    trick.active = false
    trick.hopAt = nil
    restoreAssists()
    if state.fly then
        task.wait(1)
        startFly()
    end
    if state.desync then
        desyncState = nil
        task.wait(1)
        applyDesync()
    end
end)

refreshStatus()
