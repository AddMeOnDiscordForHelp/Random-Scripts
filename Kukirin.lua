--[[
    Pulsar.One - Kukirin Life toolkit
      - Auto Wheelie  (locks the chassis pitch angle while seated)
      - Police Push   (launches PoliceNPCs away + blocks PoliceHit + auto get-up)
      - Money Farm    (auto-collects money rain parts + claims daily/quest/achievement rewards)

    Server-side validation may ignore some of this; toggle individually.
    RS -> menu, F6 -> hide
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
local MoneyRain = remote({ "MoneyRain", "Collect" })
local claimDaily = remote({ "DailyRewards", "ClaimDailyReward" })
local claimQuest = remote({ "Quests", "ClaimQuest" })
local claimAch = remote({ "Achievements", "ClaimAchievementReward" })

local state = {
    wheelie = false,
    antiPolice = false,
    money = false,
    claims = false,
    angle = 55,
    freeze = false,
    rides = nil,
    collected = 0,
    blockedHit = 0,
    claimed = 0,
    pushed = 0,
}

-- UI
local old = playerGui:FindFirstChild("PulsarKukirin")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "PulsarKukirin"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(300, 300)
frame.Position = UDim2.fromOffset(20, 160)
frame.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
local ui1 = Instance.new("UICorner"); ui1.CornerRadius = UDim.new(0, 8); ui1.Parent = frame
local ui2 = Instance.new("UIStroke"); ui2.Color = Color3.fromRGB(56,124,255); ui2.Thickness = 1; ui2.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 26); title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold; title.TextSize = 13
title.TextColor3 = Color3.fromRGB(232,238,255); title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "  Pulsar.One | Kukirin Life"
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 34); status.Position = UDim2.fromOffset(8, 28)
status.BackgroundTransparency = 1; status.Font = Enum.Font.Gotham
status.TextSize = 10; status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top; status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(150,160,180); status.Text = "loading..."
status.Parent = frame

local function mkToggle(label, y, flag, onClick)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -16, 0, 24); b.Position = UDim2.fromOffset(8, y)
    b.BackgroundColor3 = Color3.fromRGB(28, 38, 56); b.BorderSizePixel = 0
    b.Font = Enum.Font.Gotham; b.TextSize = 11
    b.TextColor3 = Color3.fromRGB(220,228,240); b.Text = "  " .. label .. ": off"
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Parent = frame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = b
    b.MouseButton1Click:Connect(function()
        pcall(function()
            state[flag] = not state[flag]
            b.Text = "  " .. label .. ": " .. (state[flag] and "on" or "off")
            b.BackgroundColor3 = state[flag] and Color3.fromRGB(40, 80, 150) or Color3.fromRGB(28,38,56)
            if onClick then onClick(state[flag]) end
        end)
    end)
    return b
end

mkToggle("auto wheelie", 66, "wheelie")
mkToggle("money farm", 122, "money")
mkToggle("auto claim rewards", 150, "claims")
mkToggle("freeze position", 178, "freeze")

-- angle slider
local sliderLabel = Instance.new("TextLabel")
sliderLabel.Size = UDim2.new(1, -16, 0, 16); sliderLabel.Position = UDim2.fromOffset(8, 204)
sliderLabel.BackgroundTransparency = 1; sliderLabel.Font = Enum.Font.Gotham
sliderLabel.TextSize = 10; sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
sliderLabel.TextColor3 = Color3.fromRGB(170,180,200); sliderLabel.Text = "wheelie angle: 55"
sliderLabel.Parent = frame

local bar = Instance.new("TextButton")
bar.Size = UDim2.new(1, -16, 0, 10); bar.Position = UDim2.fromOffset(8, 222)
bar.BackgroundColor3 = Color3.fromRGB(28,38,56); bar.BorderSizePixel = 0; bar.Text = ""
bar.Parent = frame
local barCorner = Instance.new("UICorner"); barCorner.CornerRadius = UDim.new(0,4); barCorner.Parent = bar
local fill = Instance.new("Frame")
fill.Size = UDim2.new(0.84, 0, 1, 0); fill.BackgroundColor3 = Color3.fromRGB(56,124,255)
fill.BorderSizePixel = 0; fill.Parent = bar
local fillCorner = Instance.new("UICorner"); fillCorner.CornerRadius = UDim.new(0,4); fillCorner.Parent = fill
bar.MouseButton1Click:Connect(function()
    local m = UIS:GetMouseLocation()
    local rel = math.clamp((m.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
    state.angle = -80 + rel * 160
    fill.Size = UDim2.new(rel, 0, 1, 0)
    sliderLabel.Text = string.format("wheelie angle: %.0f", state.angle)
end)

local restore = Instance.new("TextButton")
restore.Size = UDim2.new(1, -16, 0, 24); restore.Position = UDim2.fromOffset(8, 246)
restore.BackgroundColor3 = Color3.fromRGB(28,38,56); restore.BorderSizePixel = 0
restore.Font = Enum.Font.Gotham; restore.TextSize = 11
restore.TextColor3 = Color3.fromRGB(220,228,240); restore.Text = "restore hooks"
restore.Parent = frame
local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0,4); rc.Parent = restore

local function refreshStatus()
    status.Text = string.format(
        "ride: %s\ncollected: %d | police pushed: %d | claimed: %d",
        state.rides and state.rides.Name or "none",
        state.collected, state.pushed, state.claimed
    )
end

-- anti police: namecall hook on PoliceHit
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
                state.blockedHit = state.blockedHit + 1
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

mkToggle("anti police", 94, "antiPolice", function(on)
    if on then installHook() else removeHook() end
end) -- second bind keeps text in sync with hook

restore.MouseButton1Click:Connect(function()
    removeHook()
    state.antiPolice = false
end)

-- police push: grab the ragdoll module so we can undo the client ragdoll
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

                -- server keeps snapping it back -> hide it locally
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

-- helpers
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

local wheelieMover, wheelieChassis

local function findChassis(model)
    for _, d in ipairs(model:GetDescendants()) do
        if d.Name == "WheelieAtt" and d:IsA("Attachment") and d.Parent and d.Parent:IsA("BasePart") then
            return d.Parent
        end
    end
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

local function lockWheelie(model)
    local chassis = findChassis(model)
    if not chassis then return end

    if not wheelieMover or wheelieMover.Parent ~= chassis then
        if wheelieMover then pcall(function() wheelieMover:Destroy() end) end
        wheelieChassis = chassis
        wheelieMover = Instance.new("BodyAngularVelocity")
        wheelieMover.Name = "PulsarWheelieLock"
        wheelieMover.MaxTorque = Vector3.new(1e7, 1e7, 1e7)
        wheelieMover.P = 9000
        wheelieMover.D = 1500
        wheelieMover.Parent = chassis
    end

    -- hold pitch at state.angle (PD on the chassis right axis)
    local rx = select(1, chassis.CFrame:ToOrientation())
    local target = math.rad(state.angle)
    local err = math.atan2(math.sin(target - rx), math.cos(target - rx))
    local power = math.clamp(err * 14, -18, 18)
    local right = chassis.CFrame.RightVector
    wheelieMover.MaxTorque = right * 1e7
    wheelieMover.AngularVelocity = right * power

    -- lock front wheel so it doesn't roll out of the wheelie
    for _, d in ipairs(model:GetDescendants()) do
        if d.Name == "FrontLockTorque" and d:IsA("BodyAngularVelocity") then
            d.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
            d.AngularVelocity = Vector3.new(0, 0, 0)
            d.Enabled = true
        end
    end

    if state.freeze then
        local _, yaw, _ = chassis.CFrame:ToOrientation()
        chassis.CFrame = CFrame.new(chassis.Position) * CFrame.Angles(math.rad(state.angle), yaw, 0)
        chassis.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        chassis.Anchored = true
    elseif chassis.Anchored then
        chassis.Anchored = false
    end

    if WheelieState then
        pcall(function() WheelieState:FireServer(true) end)
    end
end

local function unlockWheelie()
    if wheelieMover then pcall(function() wheelieMover:Destroy() end) end
    wheelieMover = nil
    if wheelieChassis then pcall(function() wheelieChassis.Anchored = false end) end
    wheelieChassis = nil
end

-- money parts
local function collectMoney()
    local roots = {}
    for _, name in ipairs({ "MoneyRain", "Money", "Cash", "Drops", "Pickups" }) do
        local f = workspace:FindFirstChild(name)
        if f then roots[#roots + 1] = f end
    end
    if #roots == 0 then return end
    for _, root in ipairs(roots) do
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("Model") then
                local n = d.Name:lower()
                if n:find("money") or n:find("cash") or n:find("bag") or n:find("coin") then
                    if MoneyRain then
                        pcall(function() MoneyRain:FireServer(d) end)
                        pcall(function() MoneyRain:FireServer() end)
                        state.collected = state.collected + 1
                    end
                end
            end
        end
    end
end

local function claimRewards()
    local targets = { claimDaily, claimQuest, claimAch }
    for _, r in ipairs(targets) do
        if r then
            pcall(function()
                local ok = r:InvokeServer()
                if ok ~= nil then state.claimed = state.claimed + 1 end
            end)
        end
    end
end

local lastClaim = 0
RunService.Heartbeat:Connect(function()
    pcall(function()
        local ride = currentRide()
        state.rides = ride

        if state.wheelie and ride then
            lockWheelie(ride)
        else
            unlockWheelie()
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

        if state.money then collectMoney() end

        if state.claims and os.clock() - lastClaim > 5 then
            lastClaim = os.clock()
            claimRewards()
        end

        refreshStatus()
    end)
end)

UIS.InputBegan:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.F6 then
        frame.Visible = not frame.Visible
    end
end)

refreshStatus()
