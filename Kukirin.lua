--[[
    Pulsar.One | Kukirin Life
    Matcha-style Luau menu (top tabs + child panels), Pulsar.One branding.

    Features:
      RIDE      - Auto Wheelie (AlignOrientation), Auto Tricks (spin / flip farm)
      VISUALS   - Police ESP, Police Push
      MOVEMENT  - Speed Boost, Speed Uncap, CFrame Fly, Desync
      MISC      - Auto Claim, restore / stop

    F6 or Insert hides the menu. Drag the header to move it.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait(0.1); LocalPlayer = Players.LocalPlayer end
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- STATE
-- ============================================================
local state = {
    wheelie = false,
    tricks = false,
    freeze = false,
    policeEsp = false,
    antiPolice = false,
    speed = false,
    uncap = false,
    fly = false,
    desync = false,
    claims = false,
    delivery = false,
    angle = 35,
    rideSpeed = 120,
    flySpeed = 80,
    trickMode = "Spin",
    trickSpeed = 1,
    ride = nil,
    cash = 0,
    lastTrick = nil,
    pushed = 0,
    claimed = 0,
    deliveryCash = 0,
    deliveries = 0,
    deliveryStatus = "",
    deliveryCycleStart = 0,
    deliveryRide = nil,
    deliverySeat = nil,
}

local function remote(path)
    local cur = RS:FindFirstChild("Remotes")
    for _, seg in ipairs(path) do
        if not cur then return nil end
        cur = cur:FindFirstChild(seg)
    end
    return cur
end

local WheelieState = remote({ "Character", "WheelieState" })
local PoliceHit = remote({ "Character", "PoliceHit" })
local TrickState = remote({ "Tricks", "TrickState" })
local FoodDelivery = remote({ "FoodDelivery" })
local claimDaily = remote({ "DailyRewards", "ClaimDailyReward" })
local claimQuest = remote({ "Quests", "ClaimQuest" })
local claimAch = remote({ "Achievements", "ClaimAchievementReward" })

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

local function findSeat(ride)
    local seat = ride and ride:FindFirstChild("DriveSeat")
    if seat and seat:IsA("VehicleSeat") then return seat end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local s = hum and hum.SeatPart
    if s and s:IsA("VehicleSeat") then return s end
    return nil
end

-- Keeps the character rigidly attached to the vehicle while tricks / wheelie run,
-- so a wild spin cannot throw the rider off.
local seatLock = nil

local function unlockSeat()
    if seatLock then
        pcall(function() seatLock:Destroy() end)
    end
    seatLock = nil
end

local function lockSeat(seat)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not seat or not seat.Parent then
        unlockSeat()
        return
    end
    if seatLock and seatLock.Parent and seatLock.Part0 == hrp and seatLock.Part1 == seat then
        return
    end
    unlockSeat()
    seatLock = Instance.new("WeldConstraint")
    seatLock.Name = "PulsarSeatLock"
    seatLock.Part0 = hrp
    seatLock.Part1 = seat
    seatLock.Parent = hrp
end

-- ============================================================
-- AUTO WHEELIE
-- ============================================================
local wheelie = {
    active = false,
    seat = nil,
    attach = nil,
    align = nil,
    yaw = 0,
}

local function stopWheelie()
    if wheelie.align then pcall(function() wheelie.align:Destroy() end) end
    if wheelie.attach then pcall(function() wheelie.attach:Destroy() end) end
    if wheelie.seat and wheelie.seat.Parent then
        pcall(function() wheelie.seat.Anchored = false end)
    end
    wheelie.active = false
    wheelie.seat = nil
    wheelie.attach = nil
    wheelie.align = nil
    wheelie.yaw = 0
end

local function startWheelie(seat)
    stopWheelie()
    wheelie.active = true
    wheelie.seat = seat
    wheelie.yaw = select(2, seat.CFrame:ToOrientation())

    wheelie.attach = Instance.new("Attachment")
    wheelie.attach.Parent = seat

    wheelie.align = Instance.new("AlignOrientation")
    wheelie.align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    wheelie.align.Attachment0 = wheelie.attach
    wheelie.align.MaxTorque = 10000000
    wheelie.align.MaxAngularVelocity = 20
    wheelie.align.Responsiveness = 50
    wheelie.align.Parent = seat
end

local function updateWheelie(seat, dt)
    if not wheelie.align or wheelie.align.Parent ~= seat or wheelie.seat ~= seat then
        startWheelie(seat)
    end
    local steer = seat.SteerFloat or seat.Steer or 0
    wheelie.yaw = wheelie.yaw - steer * 3.0 * dt
    wheelie.align.CFrame = CFrame.new(seat.Position)
        * CFrame.Angles(0, wheelie.yaw, 0)
        * CFrame.Angles(math.rad(state.angle), 0, 0)

    if state.freeze then
        seat.Anchored = true
    elseif seat.Anchored then
        seat.Anchored = false
    end
end

-- ============================================================
-- AUTO TRICKS (jump + spin / flip cycle)
-- ============================================================
local SPIN_JUMP_VELOCITY = 15
local SPIN_ASCEND_TIME = 0.35
local SPIN_DESCENT_SPEED = -90
local SPIN_REPEAT_DELAY = 0.35
local SPIN_MAX_DESCENT_TIME = 1.6
local SPIN_GROUND_CHECK_DISTANCE = 3.5

local spin = {
    phase = "Idle",
    phaseStart = os.clock(),
    totalAngle = 0,
    targetAngle = math.rad(3000),
    rate = math.rad(3600),
    mode = "Spin",
    baseYaw = 0,
    idleAt = 0,
    currentBody = nil,
    attach = nil,
    align = nil,
    savedAutoRotate = true,
    savedPlatformStand = false,
    cycleSeated = false,
    seat = nil,
}

local function setSpinPhase(name)
    spin.phase = name
    spin.phaseStart = os.clock()
end

local function getSpinParts()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return nil end
    local seat = hum.SeatPart
    if not seat and seatLock and seatLock.Part1 and seatLock.Part1.Parent then
        seat = seatLock.Part1
    end
    if not seat and spin.seat and spin.seat.Parent then
        seat = spin.seat
    end
    local body = root
    local vehicle = nil
    if seat then
        body = seat.AssemblyRootPart or seat
        vehicle = seat:FindFirstAncestorOfClass("Model")
    end
    return char, hum, root, body, vehicle, seat
end

local function removeSpinAligner()
    if spin.align then pcall(function() spin.align:Destroy() end) end
    if spin.attach then pcall(function() spin.attach:Destroy() end) end
    spin.align = nil
    spin.attach = nil
    spin.currentBody = nil
end

local function setSpinOrientation(body, angle)
    if not body or not body.Parent then return end
    if spin.currentBody ~= body then
        removeSpinAligner()
        spin.currentBody = body
        spin.attach = Instance.new("Attachment")
        spin.attach.Parent = body
        spin.align = Instance.new("AlignOrientation")
        spin.align.Mode = Enum.OrientationAlignmentMode.OneAttachment
        spin.align.Attachment0 = spin.attach
        spin.align.Responsiveness = 300
        spin.align.MaxTorque = 1e9
        spin.align.MaxAngularVelocity = 1e6
        spin.align.Parent = body
    end

    if spin.mode == "Backflip" or spin.mode == "Frontflip" then
        spin.align.CFrame = CFrame.Angles(0, spin.baseYaw, 0) * CFrame.Angles(angle, 0, 0)
    else
        spin.align.CFrame = CFrame.Angles(0, angle, 0)
    end
end

local function setSpinVelocity(body, y)
    if body and body.Parent then
        body.AssemblyLinearVelocity = Vector3.new(0, y, 0)
    end
end

local function isSpinGrounded(char, body, vehicle)
    local filter = { char }
    if vehicle then table.insert(filter, vehicle) end
    if body and body.Parent then table.insert(filter, body) end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = filter
    return workspace:Raycast(body.Position, Vector3.new(0, -SPIN_GROUND_CHECK_DISTANCE, 0), params) ~= nil
end

local function releaseSpin(hum, body)
    removeSpinAligner()
    if hum and not spin.cycleSeated then
        hum.AutoRotate = spin.savedAutoRotate
        hum.PlatformStand = spin.savedPlatformStand
    end
    if body and body.Parent then
        body.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        body.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end
    spin.cycleSeated = false
end

local function resetSpin()
    spin.phase = "Idle"
    spin.totalAngle = 0
    spin.seat = nil
    removeSpinAligner()
end

local function stopSpin()
    local _, hum, _, body = getSpinParts()
    releaseSpin(hum, body or spin.currentBody)
    resetSpin()
    spin.idleAt = 0
end

local function chooseTrickMode()
    local mode = state.trickMode
    if mode == "Random" then
        -- keep random mode on the Y axis so the rider is not thrown off with flips
        mode = (math.random() < 0.75) and "Spin" or "180"
    end
    return mode
end

local function startSpinCycle()
    local char, hum, _, body, _, seat = getSpinParts()
    if not char then return false end

    spin.cycleSeated = seat ~= nil
    if not spin.cycleSeated then
        spin.savedAutoRotate = hum.AutoRotate
        spin.savedPlatformStand = hum.PlatformStand
        hum.AutoRotate = false
        hum.PlatformStand = true
    end

    spin.mode = chooseTrickMode()
    spin.totalAngle = 0
    spin.baseYaw = select(2, body.CFrame:ToOrientation())
    spin.seat = seat

    if spin.mode == "Spin" then
        spin.targetAngle = math.rad(1440)
        spin.rate = math.rad(720) * (state.trickSpeed or 1)
    elseif spin.mode == "Backflip" then
        spin.targetAngle = math.rad(360)
        spin.rate = math.rad(540) * (state.trickSpeed or 1)
    elseif spin.mode == "Frontflip" then
        spin.targetAngle = math.rad(-360)
        spin.rate = math.rad(-540) * (state.trickSpeed or 1)
    else
        spin.targetAngle = math.rad(180)
        spin.rate = math.rad(540) * (state.trickSpeed or 1)
    end

    setSpinOrientation(body, 0)
    setSpinVelocity(body, SPIN_JUMP_VELOCITY)
    setSpinPhase("Ascend")
    return true
end

local function updateSpin(dt)
    if not state.tricks or state.fly then
        if spin.phase ~= "Idle" then stopSpin() end
        return
    end
    if state.wheelie then
        if spin.phase ~= "Idle" then stopSpin() end
        return
    end

    local char, hum, _, body, vehicle, seat = getSpinParts()
    if not char or not seat then
        if spin.phase ~= "Idle" then
            releaseSpin(nil, spin.currentBody)
            resetSpin()
        end
        return
    end

    local now = os.clock()
    local elapsed = now - spin.phaseStart

    if spin.phase == "Idle" then
        if now - spin.idleAt >= SPIN_REPEAT_DELAY then
            startSpinCycle()
        end
    elseif spin.phase == "Ascend" then
        setSpinVelocity(body, SPIN_JUMP_VELOCITY)
        setSpinOrientation(body, 0)
        if elapsed >= SPIN_ASCEND_TIME then setSpinPhase("Spin") end
    elseif spin.phase == "Spin" then
        setSpinVelocity(body, 0)
        spin.totalAngle = spin.totalAngle + spin.rate * dt
        if math.abs(spin.totalAngle) >= math.abs(spin.targetAngle) then
            spin.totalAngle = spin.targetAngle
            setSpinPhase("Descend")
        end
        setSpinOrientation(body, spin.totalAngle)
    elseif spin.phase == "Descend" then
        setSpinVelocity(body, SPIN_DESCENT_SPEED)
        setSpinOrientation(body, spin.targetAngle)
        if isSpinGrounded(char, body, vehicle) or elapsed >= SPIN_MAX_DESCENT_TIME then
            setSpinPhase("Landed")
        end
    elseif spin.phase == "Landed" then
        setSpinVelocity(body, 0)
        if elapsed >= 0.05 then
            releaseSpin(hum, body)
            spin.totalAngle = 0
            spin.idleAt = now
            setSpinPhase("Idle")
        end
    end
end

if TrickState then
    TrickState.OnClientEvent:Connect(function(kind, name, amount)
        if kind == "landed" then
            if name then state.lastTrick = name end
            if type(amount) == "number" and amount > 0 then
                state.cash = state.cash + amount
            end
        elseif kind == "air" or kind == "landing" then
            if name then state.lastTrick = name end
        end
    end)
end

-- ============================================================
-- POLICE PUSH
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

local policeHighlights, policeTags, policeBoxes = {}, {}, {}

local oldEspGui = playerGui:FindFirstChild("PulsarKukirinESP")
if oldEspGui then oldEspGui:Destroy() end
local espGui = Instance.new("ScreenGui")
espGui.Name = "PulsarKukirinESP"
espGui.ResetOnSpawn = false
espGui.IgnoreGuiInset = true
espGui.DisplayOrder = 998
espGui.Parent = playerGui

local function clearPoliceEsp()
    for model, h in pairs(policeHighlights) do
        pcall(function() h:Destroy() end)
        policeHighlights[model] = nil
    end
    for model, t in pairs(policeTags) do
        pcall(function() t:Destroy() end)
        policeTags[model] = nil
    end
    for model, b in pairs(policeBoxes) do
        pcall(function() b:Destroy() end)
        policeBoxes[model] = nil
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

            local box = policeBoxes[model]
            if not box or not box.Parent then
                box = Instance.new("Frame")
                box.Name = "PulsarPoliceBox"
                box.BackgroundTransparency = 1
                box.BorderSizePixel = 0
                box.Visible = false
                box.ZIndex = 5
                local boxStroke = Instance.new("UIStroke")
                boxStroke.Color = Color3.fromRGB(255, 60, 60)
                boxStroke.Thickness = 1.5
                boxStroke.Parent = box
                box.Parent = espGui
                policeBoxes[model] = box
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
    for model, b in pairs(policeBoxes) do
        if not live[model] then
            pcall(function() b:Destroy() end)
            policeBoxes[model] = nil
        end
    end
end

local function updatePoliceBoxes()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize

    for model, box in pairs(policeBoxes) do
        if not model.Parent then
            box.Visible = false
        else
            local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
            if not ok or typeof(cf) ~= "CFrame" or typeof(size) ~= "Vector3" or size.Magnitude < 0.1 then
                box.Visible = false
            else
                local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
                local corners = {
                    cf * Vector3.new(-hx, -hy, -hz),
                    cf * Vector3.new(-hx, -hy, hz),
                    cf * Vector3.new(-hx, hy, -hz),
                    cf * Vector3.new(-hx, hy, hz),
                    cf * Vector3.new(hx, -hy, -hz),
                    cf * Vector3.new(hx, -hy, hz),
                    cf * Vector3.new(hx, hy, -hz),
                    cf * Vector3.new(hx, hy, hz),
                }

                local minX, minY = math.huge, math.huge
                local maxX, maxY = -math.huge, -math.huge
                local any = false

                for _, world in ipairs(corners) do
                    local screen = cam:WorldToViewportPoint(world)
                    if screen.Z > 0 then
                        any = true
                        minX = math.min(minX, screen.X)
                        minY = math.min(minY, screen.Y)
                        maxX = math.max(maxX, screen.X)
                        maxY = math.max(maxY, screen.Y)
                    end
                end

                if any then
                    minX = math.clamp(minX, -100, vp.X + 100)
                    minY = math.clamp(minY, -100, vp.Y + 100)
                    maxX = math.clamp(maxX, -100, vp.X + 100)
                    maxY = math.clamp(maxY, -100, vp.Y + 100)
                    box.Position = UDim2.fromOffset(math.floor(minX), math.floor(minY))
                    box.Size = UDim2.fromOffset(math.max(2, math.floor(maxX - minX)), math.max(2, math.floor(maxY - minY)))
                    box.Visible = true
                else
                    box.Visible = false
                end
            end
        end
    end
end

-- ============================================================
-- POLICEHIT HOOK
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

local function applySpeed(dt)
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

    if (state.speed or state.uncap) and hum.SeatPart and not state.fly and not state.tricks and not state.delivery then
        local seat = hum.SeatPart
        if seat and seat:IsA("VehicleSeat") then
            local throttle = seat.ThrottleFloat or seat.Throttle or 0
            if throttle > 0 then
                local target = state.uncap and math.min(state.rideSpeed * 4, 1500) or state.rideSpeed
                local body = seat.AssemblyRootPart or seat
                local v = body.AssemblyLinearVelocity
                local look = seat.CFrame.LookVector
                local flat = Vector3.new(look.X, 0, look.Z)
                if flat.Magnitude > 0.1 then
                    if state.uncap then
                        body.AssemblyLinearVelocity = flat.Unit * target + Vector3.new(0, v.Y, 0)
                    else
                        local push = state.rideSpeed * 0.5
                        body.AssemblyLinearVelocity = body.AssemblyLinearVelocity + flat.Unit * push * dt
                    end
                end
            end
        end
    end
end

-- ============================================================
-- CFRAME FLY
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
                if ok and (name == "CameraModule" or name == "FirstPersonCamera") then
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
-- PIZZA DELIVERY FARM
-- ============================================================
local DELIVERY_NPC = Vector3.new(1424.7, 58.6, -607.8)
local DELIVERY_CYCLE = 20

local function teleportTo(pos)
    if typeof(pos) ~= "Vector3" then return end
    pcall(function() workspace:RequestStreamAroundAsync(pos) end)

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local seat = hum and hum.SeatPart
    local ride = seat and seat:FindFirstAncestorOfClass("Model")

    if ride then
        local pivot = ride:GetPivot()
        ride:PivotTo(CFrame.new(pos + Vector3.new(0, 5, 0)) * (pivot - pivot.Position))
        local body = ride.PrimaryPart or seat
        if body then
            body.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            body.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    elseif root then
        root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
end

local deliveryToken = {}
getgenv().pulsarKukirinDeliveryToken = deliveryToken

local function tweenTo(pos, duration)
    if typeof(pos) ~= "Vector3" then return end
    duration = math.max(0.5, duration or 1)
    pcall(function() workspace:RequestStreamAroundAsync(pos) end)

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local seat = hum and hum.SeatPart
    local ride = seat and seat:FindFirstAncestorOfClass("Model")

    if ride then
        state.deliveryRide = ride
        state.deliverySeat = seat
        local body = ride.PrimaryPart or seat
        local pivot = ride:GetPivot()
        local goal = CFrame.new(pos + Vector3.new(0, 5, 0)) * (pivot - pivot.Position)
        local value = Instance.new("CFrameValue")
        value.Value = pivot
        local connection = value:GetPropertyChangedSignal("Value"):Connect(function()
            if ride.Parent then
                pcall(function() ride:PivotTo(value.Value) end)
            end
        end)

        local wasAnchored = body and body.Anchored
        if body then body.Anchored = true end

        local tween = TweenService:Create(
            value,
            TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            { Value = goal }
        )
        tween:Play()
        tween.Completed:Wait()

        if connection then connection:Disconnect() end
        value:Destroy()

        if body and body.Parent then
            body.Anchored = wasAnchored
            body.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            body.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    elseif root then
        local wasAnchored = root.Anchored
        root.Anchored = true
        local tween = TweenService:Create(
            root,
            TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            { CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) }
        )
        tween:Play()
        tween.Completed:Wait()
        if root.Parent then
            root.Anchored = wasAnchored
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end
end

local function dismountForDelivery()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or not hum.SeatPart then return end

    state.deliverySeat = hum.SeatPart
    state.deliveryRide = hum.SeatPart:FindFirstAncestorOfClass("Model")
    state.deliveryStatus = "jumping off at customer"

    pcall(function() hum.Sit = false end)
    task.wait(0.12)
    if hum.SeatPart then
        root.CFrame = hum.SeatPart.CFrame * CFrame.new(0, 4, 6)
        pcall(function() hum.Sit = false end)
        task.wait(0.1)
    end
    pcall(function() hum.Jump = true end)
    if root.Parent then
        root.AssemblyLinearVelocity = root.AssemblyLinearVelocity + Vector3.new(0, 28, 0)
    end
    task.wait(0.35)
end

local function remountDeliveryRide()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.SeatPart then return end

    local ride = state.deliveryRide
    local seat = state.deliverySeat
    if (not seat or not seat.Parent) and ride and ride.Parent then
        seat = ride:FindFirstChild("DriveSeat")
    end
    if not seat or not seat.Parent then return end

    state.deliveryStatus = "jumping back on"
    pcall(function()
        if hum:GetState() == Enum.HumanoidStateType.Physics then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)

    root.CFrame = seat.CFrame * CFrame.new(0, 3, 0)
    task.wait(0.1)
    pcall(function() seat:Sit(hum) end)
    task.wait(0.2)

    if not hum.SeatPart then
        pcall(function() hum.Sit = true end)
        task.wait(0.2)
    end

    state.deliverySeat = seat
end

local function deliveryLoop()
    while getgenv().pulsarKukirinDeliveryToken == deliveryToken do
        if state.delivery and FoodDelivery and FoodDelivery:FindFirstChild("Start") and FoodDelivery:FindFirstChild("Deliver") then
            local target = LocalPlayer:GetAttribute("DeliveryTarget")

            if typeof(target) ~= "Vector3" then
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if state.deliveryRide and not (hum and hum.SeatPart) then
                    remountDeliveryRide()
                end
                state.deliveryStatus = "tweening to delivery NPC"
                tweenTo(DELIVERY_NPC, 2.5)
                task.wait(0.2)
                if not state.delivery then
                    state.deliveryStatus = ""
                else
                    local ok, started, msg = pcall(function()
                        return FoodDelivery.Start:InvokeServer()
                    end)

                    if ok and started then
                        state.deliveryCycleStart = os.clock()
                        state.deliveryStatus = "picked up an order"
                    else
                        state.deliveryStatus = tostring(msg or "waiting for an order")
                        task.wait(1.5)
                    end
                end
            else
                local cycleStart = state.deliveryCycleStart
                if cycleStart == 0 then
                    cycleStart = os.clock()
                    state.deliveryCycleStart = cycleStart
                end

                local elapsed = os.clock() - cycleStart
                local travel = math.clamp(16.5 - elapsed, 2, 16.5)

                state.deliveryStatus = "tweening to customer"
                tweenTo(target + Vector3.new(0, 0, 4), travel)
                dismountForDelivery()
                state.deliveryStatus = "waiting for drop-off"

                local targetTime = cycleStart + DELIVERY_CYCLE
                local giveUp = math.max(targetTime, os.clock() + 5) + 18

                while state.delivery
                    and getgenv().pulsarKukirinDeliveryToken == deliveryToken
                    and LocalPlayer:GetAttribute("DeliveryTarget") == target
                    and os.clock() < giveUp do

                    local ok, done, pay, _, tip = pcall(function()
                        return FoodDelivery.Deliver:InvokeServer()
                    end)

                    if ok and done then
                        local earned = (tonumber(pay) or 0) + (tonumber(tip) or 0)
                        state.deliveryCash = state.deliveryCash + earned
                        state.deliveries = state.deliveries + 1
                        state.deliveryStatus = string.format("delivered +$%d", earned)
                        state.deliveryCycleStart = 0
                        remountDeliveryRide()
                        break
                    end

                    if os.clock() >= targetTime then
                        state.deliveryStatus = "waiting for server payout"
                    end

                    task.wait(0.75)
                end

                if state.delivery and LocalPlayer:GetAttribute("DeliveryTarget") == target then
                    state.deliveryStatus = "deliver rejected, retrying"
                    state.deliveryCycleStart = 0
                    task.wait(0.5)
                end
            end
        else
            state.deliveryStatus = ""
            state.deliveryCycleStart = 0
            task.wait(0.5)
        end

        task.wait(0.1)
    end
end

task.spawn(deliveryLoop)

-- ============================================================
-- MATCHA-STYLE UI
-- ============================================================
local ACCENT = Color3.fromRGB(72, 132, 255)
local BG = Color3.fromRGB(23, 23, 31)
local PANEL = Color3.fromRGB(27, 28, 39)
local PANEL2 = Color3.fromRGB(35, 37, 49)
local BORDER = Color3.fromRGB(40, 42, 56)
local TEXT = Color3.fromRGB(236, 236, 244)
local LABEL = Color3.fromRGB(122, 131, 165)
local MUTED = Color3.fromRGB(88, 94, 120)
local FONT = Enum.Font.Gotham
local FONT_MED = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

local function new(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    if parent then inst.Parent = parent end
    return inst
end

local old = playerGui:FindFirstChild("PulsarKukirin")
if old then old:Destroy() end

local gui = new("ScreenGui", {
    Name = "PulsarKukirin",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local cam = workspace.CurrentCamera or workspace:WaitForChild("CurrentCamera")
local vp = cam.ViewportSize
local WIN_W, WIN_H = 660, 470

local glow = new("Frame", {
    Size = UDim2.fromOffset(WIN_W + 14, WIN_H + 14),
    Position = UDim2.fromOffset(math.floor((vp.X - WIN_W) / 2) - 7, math.floor((vp.Y - WIN_H) / 2) - 7),
    BackgroundColor3 = ACCENT,
    BackgroundTransparency = 0.90,
    BorderSizePixel = 0,
    ZIndex = 0,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 22) }, glow)

local win = new("Frame", {
    Size = UDim2.fromOffset(WIN_W, WIN_H),
    Position = UDim2.fromOffset(math.floor((vp.X - WIN_W) / 2), math.floor((vp.Y - WIN_H) / 2)),
    BackgroundColor3 = BG,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
    ZIndex = 1,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 16) }, win)
new("UIStroke", { Color = BORDER, Thickness = 1 }, win)

local uiScale = new("UIScale", {}, win)
local function fitScale()
    local size = cam.ViewportSize
    local s = math.min(1, (size.X - 40) / WIN_W, (size.Y - 40) / WIN_H)
    uiScale.Scale = math.clamp(s, 0.6, 1)
end
fitScale()
cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    pcall(fitScale)
end)

-- top accent line
new("Frame", {
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = ACCENT,
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
    ZIndex = 2,
}, win)

-- header / drag strip
local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 56),
    BackgroundTransparency = 1,
    Active = true,
    ZIndex = 3,
}, win)

local logoDot = new("Frame", {
    Position = UDim2.fromOffset(20, 20),
    Size = UDim2.fromOffset(6, 6),
    BackgroundColor3 = ACCENT,
    BorderSizePixel = 0,
}, header)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, logoDot)

local logo = new("TextLabel", {
    Position = UDim2.fromOffset(32, 12),
    Size = UDim2.new(0, 240, 0, 22),
    BackgroundTransparency = 1,
    Font = FONT_BOLD,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    RichText = true,
    Text = '<font color="#ffffff">PULSAR</font><font color="#4884ff">.ONE</font>',
    ZIndex = 4,
}, header)

local subtitle = new("TextLabel", {
    Position = UDim2.fromOffset(34, 34),
    Size = UDim2.new(0, 260, 0, 14),
    BackgroundTransparency = 1,
    Font = FONT_MED,
    TextSize = 9,
    TextColor3 = LABEL,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "KUKIRIN LIFE",
    ZIndex = 4,
}, header)

local close = new("TextButton", {
    Position = UDim2.new(1, -36, 0, 14),
    Size = UDim2.fromOffset(22, 22),
    BackgroundTransparency = 1,
    Font = FONT_MED,
    TextSize = 18,
    TextColor3 = MUTED,
    Text = "x",
    ZIndex = 4,
}, header)
close.MouseButton1Click:Connect(function() win.Visible = false end)

local dragStart, startPos = nil, nil
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragStart = input.Position
        startPos = win.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        local nx = startPos.X.Offset + delta.X
        local ny = startPos.Y.Offset + delta.Y
        local size = cam.ViewportSize
        nx = math.clamp(nx, 8, math.max(8, size.X - win.AbsoluteSize.X - 8))
        ny = math.clamp(ny, 8, math.max(8, size.Y - win.AbsoluteSize.Y - 8))
        win.Position = UDim2.fromOffset(nx, ny)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragStart = nil
    end
end)

-- navigation
local nav = new("Frame", {
    Position = UDim2.fromOffset(18, 58),
    Size = UDim2.new(1, -36, 0, 32),
    BackgroundTransparency = 1,
    ZIndex = 3,
}, win)

new("Frame", {
    Position = UDim2.new(0, 0, 0, 31),
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = BORDER,
    BackgroundTransparency = 0.25,
    BorderSizePixel = 0,
    ZIndex = 3,
}, nav)

local tabButtons = {}
local tabFrames = {}
local tabOrder = { "ride", "farm", "visuals", "movement", "misc" }
local tabLabels = { "RIDE", "FARM", "VISUALS", "MOVEMENT", "MISC" }
local activeTab = "ride"

local content = new("Frame", {
    Position = UDim2.fromOffset(16, 96),
    Size = UDim2.new(1, -32, 1, -142),
    BackgroundTransparency = 1,
    ZIndex = 3,
}, win)

local function makeTab(name)
    local f = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = (name == activeTab),
        ZIndex = 3,
    }, content)
    tabFrames[name] = f
    return f
end

local tabUnderlines = {}

local function switchTab(name)
    activeTab = name
    for k, f in pairs(tabFrames) do
        f.Visible = (k == name)
    end
    for k, b in pairs(tabButtons) do
        b.TextColor3 = (k == name) and TEXT or LABEL
        local u = tabUnderlines[k]
        if u then u.Visible = (k == name) end
    end
end

for i, name in ipairs(tabOrder) do
    local b = new("TextButton", {
        Position = UDim2.fromOffset((i - 1) * 88, 0),
        Size = UDim2.fromOffset(80, 31),
        BackgroundTransparency = 1,
        Font = FONT_MED,
        TextSize = 10,
        TextColor3 = (name == activeTab) and TEXT or LABEL,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = tabLabels[i],
        ZIndex = 4,
    }, nav)
    local ul = new("Frame", {
        Position = UDim2.fromOffset(0, 29),
        Size = UDim2.fromOffset(28, 2),
        BackgroundColor3 = ACCENT,
        BorderSizePixel = 0,
        Visible = (name == activeTab),
        ZIndex = 5,
    }, b)
    tabUnderlines[name] = ul
    b.MouseButton1Click:Connect(function() switchTab(name) end)
    tabButtons[name] = b
end

local rideTab = makeTab("ride")
local farmTab = makeTab("farm")
local visualsTab = makeTab("visuals")
local movementTab = makeTab("movement")
local miscTab = makeTab("misc")

-- widgets
local toggleWidgets = {}
local statusLabels = {}

local function setToggle(key, value)
    local w = toggleWidgets[key]
    if w then
        if state[key] ~= value then w.apply(value) end
    else
        state[key] = value
    end
end

local function makePanel(parent, title, x, y, w, h)
    local p = new("Frame", {
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = PANEL,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, parent)
    new("UICorner", { CornerRadius = UDim.new(0, 12) }, p)
    new("UIStroke", { Color = BORDER, Thickness = 1 }, p)

    local bar = new("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        ZIndex = 4,
    }, p)
    new("TextLabel", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 1, 0),
        BackgroundTransparency = 1,
        Font = FONT_BOLD,
        TextSize = 11,
        TextColor3 = ACCENT,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = title,
        ZIndex = 5,
    }, bar)
    new("Frame", {
        Position = UDim2.fromOffset(0, 29),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = ACCENT,
        BackgroundTransparency = 0.72,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, p)

    return new("Frame", {
        Position = UDim2.fromOffset(10, 38),
        Size = UDim2.new(1, -20, 1, -46),
        BackgroundTransparency = 1,
        ZIndex = 4,
    }, p)
end

local function makeToggle(parent, key, label, y, onChange)
    local row = new("TextButton", {
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 5,
    }, parent)

    local lab = new("TextLabel", {
        Size = UDim2.new(1, -56, 1, 0),
        BackgroundTransparency = 1,
        Font = FONT,
        TextSize = 11,
        TextColor3 = LABEL,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = label,
        ZIndex = 5,
    }, row)

    local pill = new("Frame", {
        Position = UDim2.new(1, -38, 0, 5),
        Size = UDim2.fromOffset(34, 18),
        BackgroundColor3 = PANEL2,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, row)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)

    local knob = new("Frame", {
        Position = UDim2.fromOffset(2, 2),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = TEXT,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, pill)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

    local function apply(on)
        state[key] = on
        pill.BackgroundColor3 = on and ACCENT or PANEL2
        lab.TextColor3 = on and TEXT or LABEL
        TweenService:Create(knob, TweenInfo.new(0.12), {
            Position = UDim2.fromOffset(on and 18 or 2, 2),
        }):Play()
    end

    local function flip()
        local on = not state[key]
        apply(on)
        if onChange then onChange(on) end
    end

    row.MouseButton1Click:Connect(flip)
    toggleWidgets[key] = { apply = apply, flip = flip }
    apply(state[key])
end

local function makeSlider(parent, key, label, minimum, maximum, step, y, fmt)
    local row = new("Frame", {
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
        ZIndex = 5,
    }, parent)

    new("TextLabel", {
        Size = UDim2.new(1, -60, 0, 16),
        BackgroundTransparency = 1,
        Font = FONT,
        TextSize = 11,
        TextColor3 = LABEL,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = label,
        ZIndex = 5,
    }, row)

    local valueLabel = new("TextLabel", {
        Position = UDim2.new(1, -60, 0, 0),
        Size = UDim2.fromOffset(60, 16),
        BackgroundTransparency = 1,
        Font = FONT,
        TextSize = 10,
        TextColor3 = TEXT,
        TextXAlignment = Enum.TextXAlignment.Right,
        Text = "",
        ZIndex = 5,
    }, row)

    local track = new("Frame", {
        Position = UDim2.fromOffset(0, 22),
        Size = UDim2.new(1, 0, 0, 4),
        BackgroundColor3 = PANEL2,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, row)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)

    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = ACCENT,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, track)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(10, 10),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = TEXT,
        BorderSizePixel = 0,
        ZIndex = 7,
    }, track)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

    local hit = new("TextButton", {
        Position = UDim2.fromOffset(0, 13),
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 8,
    }, row)

    local function setValue(v)
        v = math.clamp(v, minimum, maximum)
        if step and step > 0 then
            v = math.floor(v / step + 0.5) * step
        end
        state[key] = v
        local rel = (v - minimum) / (maximum - minimum)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        valueLabel.Text = string.format(fmt or "%.0f", v)
    end

    local function seek(input)
        local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        setValue(minimum + rel * (maximum - minimum))
    end

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            seek(input)
            local moveConn
            local endConn
            moveConn = UIS.InputChanged:Connect(function(m)
                if m.UserInputType == Enum.UserInputType.MouseMovement or m.UserInputType == Enum.UserInputType.Touch then
                    seek(m)
                end
            end)
            endConn = UIS.InputEnded:Connect(function(e)
                if e.UserInputType == Enum.UserInputType.MouseButton1 or e.UserInputType == Enum.UserInputType.Touch then
                    if moveConn then moveConn:Disconnect() end
                    if endConn then endConn:Disconnect() end
                end
            end)
        end
    end)

    setValue(state[key] or minimum)
    return { set = setValue }
end

local function makeInfo(parent, y, h, text)
    return new("TextLabel", {
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, h),
        BackgroundTransparency = 1,
        Font = FONT,
        TextSize = 10,
        TextColor3 = MUTED,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Text = text,
        ZIndex = 5,
    }, parent)
end

local function makeButton(parent, label, y, callback)
    local b = new("TextButton", {
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = PANEL2,
        BorderSizePixel = 0,
        Font = FONT_MED,
        TextSize = 10,
        TextColor3 = TEXT,
        Text = label,
        ZIndex = 5,
    }, parent)
    new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
    b.MouseEnter:Connect(function() b.BackgroundColor3 = Color3.fromRGB(44, 47, 62) end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = PANEL2 end)
    if callback then b.MouseButton1Click:Connect(callback) end
    return b
end

local TRICK_MODES = { "Random", "Spin", "Backflip", "Frontflip", "180" }

local function makeModeButton(parent, y)
    new("TextLabel", {
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, -110, 0, 24),
        BackgroundTransparency = 1,
        Font = FONT,
        TextSize = 11,
        TextColor3 = LABEL,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Mode",
        ZIndex = 5,
    }, parent)

    local b = new("TextButton", {
        Position = UDim2.new(1, -104, y, 0),
        Size = UDim2.fromOffset(104, 22),
        BackgroundColor3 = PANEL2,
        BorderSizePixel = 0,
        Font = FONT_MED,
        TextSize = 10,
        TextColor3 = TEXT,
        Text = state.trickMode,
        ZIndex = 5,
    }, parent)
    new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)

    b.MouseButton1Click:Connect(function()
        local idx = 1
        for i, m in ipairs(TRICK_MODES) do
            if m == state.trickMode then idx = i; break end
        end
        state.trickMode = TRICK_MODES[idx % #TRICK_MODES + 1]
        b.Text = state.trickMode
    end)
end

-- RIDE TAB
local wc = makePanel(rideTab, "AUTO WHEELIE", 0, 0, 308, 170)
makeToggle(wc, "wheelie", "Enable", 0, function(on)
    if on then
        setToggle("tricks", false)
        setToggle("delivery", false)
        stopSpin()
    end
end)
makeSlider(wc, "angle", "Angle", -80, 80, 1, 32, "%.0f deg")
makeToggle(wc, "freeze", "Freeze position", 76)

local sl = makePanel(rideTab, "SEAT LOCK", 320, 0, 308, 170)
makeInfo(sl, 0, 110, "A WeldConstraint pins your HumanoidRootPart to the seat while wheelie or tricks run, so the vehicle cannot fling you off. It is removed when both are off.")

local rsPanel = makePanel(rideTab, "RIDE STATUS", 0, 182, 628, 120)
local rideStatus = makeInfo(rsPanel, 0, 70, "waiting...")
table.insert(statusLabels, rideStatus)

-- FARM TAB
local tc = makePanel(farmTab, "AUTO TRICKS", 0, 0, 308, 170)
makeToggle(tc, "tricks", "Enable", 0, function(on)
    if on then
        setToggle("wheelie", false)
        setToggle("delivery", false)
        stopWheelie()
    end
end)
makeModeButton(tc, 32)
makeSlider(tc, "trickSpeed", "Spin speed", 0.3, 1.5, 0.1, 64, "x%.1f")
local trickInfo = makeInfo(tc, 104, 20, "Mode: Spin")

local dp = makePanel(farmTab, "PIZZA DELIVERY", 320, 0, 308, 170)
makeToggle(dp, "delivery", "Auto delivery", 0, function(on)
    if on then
        setToggle("wheelie", false)
        setToggle("tricks", false)
        setToggle("fly", false)
        stopWheelie()
        stopSpin()
        if flyPos then stopFly() end
    end
end)
makeButton(dp, "Teleport to delivery NPC", 34, function() teleportTo(DELIVERY_NPC) end)
makeInfo(dp, 66, 52, "Starts an order, jumps off at the customer, delivers, then remounts for the return.")

local dstat = makePanel(farmTab, "DELIVERY STATUS", 0, 182, 308, 120)
local deliveryStatusLabel = makeInfo(dstat, 0, 40, "idle")
local deliveryStatsLabel = makeInfo(dstat, 44, 30, "deliveries: 0 · cash: $0")

local dnote = makePanel(farmTab, "NOTES", 320, 182, 308, 120)
makeInfo(dnote, 0, 70, "20s tweened cycle. Jumps off at the customer and back on for the return. Server payout can still take ~30s.")

-- VISUALS TAB
local pe = makePanel(visualsTab, "POLICE ESP", 0, 0, 308, 170)
makeToggle(pe, "policeEsp", "Enable", 0, function(on)
    if on then updatePoliceEsp() else clearPoliceEsp() end
end)
makeInfo(pe, 34, 80, "Red highlight + POLICE tag on Workspace.PoliceNPCs.")

local pp = makePanel(visualsTab, "POLICE PUSH", 320, 0, 308, 170)
makeToggle(pp, "antiPolice", "Enable", 0)
makeInfo(pp, 34, 80, "Launches police cars away, disables their touch and blocks PoliceHit.")

local vn = makePanel(visualsTab, "NOTES", 0, 182, 628, 120)
makeInfo(vn, 0, 70, "Police push is client-side. Server AI still exists, but police cars cannot touch you locally.")

-- MOVEMENT TAB
local sp = makePanel(movementTab, "SPEED", 0, 0, 308, 190)
makeToggle(sp, "speed", "Speed boost", 0)
makeToggle(sp, "uncap", "Speed uncap", 32)
makeSlider(sp, "rideSpeed", "Ride speed", 30, 300, 5, 64, "%.0f")
makeInfo(sp, 106, 36, "Hold throttle to apply.")

local fl = makePanel(movementTab, "FLIGHT", 320, 0, 308, 190)
makeToggle(fl, "fly", "CFrame fly", 0, function(on)
    if on then
        setToggle("wheelie", false)
        setToggle("tricks", false)
        setToggle("delivery", false)
        stopWheelie()
        stopSpin()
    end
end)
makeSlider(fl, "flySpeed", "Fly speed", 10, 500, 5, 32, "%.0f")
makeInfo(fl, 74, 70, "WASD + Space/Ctrl. Camera-relative CFrame movement.")

local ds = makePanel(movementTab, "DESYNC", 0, 202, 628, 110)
makeToggle(ds, "desync", "Enable", 0)
makeInfo(ds, 34, 28, "CameraModule / FirstPersonCamera sees a 90-degree rotated root.")

-- MISC TAB
local rw = makePanel(miscTab, "REWARDS", 0, 0, 308, 170)
makeToggle(rw, "claims", "Auto claim", 0)
makeButton(rw, "Claim now", 34, function() claimRewards() end)
makeInfo(rw, 72, 46, "Daily, quests and achievements.")

local cfg = makePanel(miscTab, "CONFIG", 320, 0, 308, 170)
local restoreBtn = makeButton(cfg, "Restore hooks / stop", 0, nil)
makeInfo(cfg, 38, 80, "F6 or Insert hides. Drag the header. Pulsar.One for Kukirin Life.")

local st = makePanel(miscTab, "STATUS", 0, 182, 628, 120)
local miscStatus = makeInfo(st, 0, 70, "waiting...")
table.insert(statusLabels, miscStatus)

-- FOOTER
local footer = new("Frame", {
    Position = UDim2.new(0, 0, 1, -34),
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundTransparency = 1,
    ZIndex = 3,
}, win)
new("Frame", {
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = BORDER,
    BackgroundTransparency = 0.25,
    BorderSizePixel = 0,
    ZIndex = 3,
}, footer)

local footLeft = new("TextLabel", {
    Position = UDim2.fromOffset(18, 0),
    Size = UDim2.new(0.72, 0, 1, 0),
    BackgroundTransparency = 1,
    Font = FONT,
    TextSize = 10,
    TextColor3 = LABEL,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "loading...",
    ZIndex = 4,
}, footer)
table.insert(statusLabels, footLeft)

local footRight = new("TextLabel", {
    Position = UDim2.new(0.72, 0, 0, 0),
    Size = UDim2.new(0.28, -18, 1, 0),
    BackgroundTransparency = 1,
    Font = FONT,
    TextSize = 10,
    TextColor3 = MUTED,
    TextXAlignment = Enum.TextXAlignment.Right,
    Text = "Pulsar.One · F6",
    ZIndex = 4,
}, footer)

local function refreshStatus()
    local text = string.format(
        "ride: %s   ·   tricks $%d   ·   pizza $%d   ·   last: %s",
        state.ride and state.ride.Name or "none",
        state.cash,
        state.deliveryCash,
        state.lastTrick or "none"
    )
    for _, label in ipairs(statusLabels) do
        if label.Parent then label.Text = text end
    end
    footRight.Text = string.format("pushed %d · delivered %d · F6", state.pushed, state.deliveries)

    if deliveryStatusLabel then
        deliveryStatusLabel.Text = state.deliveryStatus ~= "" and state.deliveryStatus
            or (state.delivery and "starting..." or "idle")
    end
    if deliveryStatsLabel then
        deliveryStatsLabel.Text = string.format("deliveries: %d · cash: $%d", state.deliveries, state.deliveryCash)
    end
    if trickInfo then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if state.tricks and not (hum and hum.SeatPart) then
            trickInfo.Text = "Sit on a ride first."
        else
            trickInfo.Text = string.format("Mode: %s", state.trickMode)
        end
    end
end

-- ============================================================
-- RESTORE
-- ============================================================
local function restoreAll()
    unlockSeat()
    stopWheelie()
    stopSpin()
    stopFly()
    removeDesync()
    removeHook()
    for key in pairs(toggleWidgets) do
        setToggle(key, false)
    end
    refreshStatus()
end
restoreBtn.MouseButton1Click:Connect(restoreAll)

-- ============================================================
-- LOOPS
-- ============================================================
local lastEsp, lastClaim, lastStatus = 0, 0, 0

RunService.Heartbeat:Connect(function(dt)
    pcall(function()
        local ride = currentRide()
        state.ride = ride

        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local rideSeat = ride and findSeat(ride) or (hum and hum.SeatPart)
        if not rideSeat and seatLock and seatLock.Part1 and seatLock.Part1.Parent then
            rideSeat = seatLock.Part1
        end
        if not rideSeat and spin.seat and spin.seat.Parent then
            rideSeat = spin.seat
        end
        if (state.wheelie or state.tricks) and rideSeat and not state.fly then
            lockSeat(rideSeat)
        else
            unlockSeat()
        end
        if (state.wheelie or state.tricks) and hum and hum:GetState() == Enum.HumanoidStateType.Physics then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end

        -- wheelie
        if state.wheelie and ride and not state.tricks and not state.fly then
            local seat = findSeat(ride)
            if seat then
                if not wheelie.active or wheelie.seat ~= seat then startWheelie(seat) end
                updateWheelie(seat, dt)
            end
        elseif wheelie.active then
            stopWheelie()
        end

        -- tricks
        if state.tricks and not state.fly then
            updateSpin(dt)
        elseif spin.phase ~= "Idle" then
            stopSpin()
        end

        -- police push
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
        elseif hookOn then
            removeHook()
        end

        -- police esp
        if os.clock() - lastEsp > 1 then
            lastEsp = os.clock()
            updatePoliceEsp()
        end

        -- claims
        if state.claims and os.clock() - lastClaim > 5 then
            lastClaim = os.clock()
            claimRewards()
        end

        -- speed
        applySpeed(dt)

        -- desync
        if state.desync then
            if not desyncState then applyDesync() end
        elseif desyncState then
            removeDesync()
        end

        -- fly start/stop
        if state.fly then
            if not flyPos then startFly() end
        elseif flyPos then
            stopFly()
        end

        -- status
        if os.clock() - lastStatus > 0.25 then
            lastStatus = os.clock()
            refreshStatus()
        end
    end)
end)

RunService.RenderStepped:Connect(function(dt)
    if state.fly then pcall(updateFly, dt) end
    if state.policeEsp then pcall(updatePoliceBoxes) end
end)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.F6 or input.KeyCode == Enum.KeyCode.Insert then
            win.Visible = not win.Visible
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    unlockSeat()
    flyPos, flyHum = nil, nil
    table.clear(flySavedParts)
    spin.phase = "Idle"
    spin.totalAngle = 0
    spin.currentBody = nil
    spin.attach = nil
    spin.align = nil
    if wheelie.active then stopWheelie() end

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
