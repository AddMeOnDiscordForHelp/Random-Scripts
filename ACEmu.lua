--[[
    Pulsar.One - local AC emulator (test only)
    Simulates the client AC signals we identified in Fust:
      - FpsProbe        (fps, stalls, menu/world state)
      - ClientShield    (FustAnimShield / FustCharSync enabled)
      - DeviceReport    (input-device switching)
      - MotionSync      (camera vs body yaw mismatch)
    Nothing is sent to the server. Score is heuristic until we decompile
    FustFpsProbe / FustControls / FustAcLab with PSMS.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait(0.1); LocalPlayer = Players.LocalPlayer end

local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("PulsarACEmu")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "PulsarACEmu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = playerGui

local function new(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then pcall(function() inst[k] = v end) end
    end
    inst.Parent = props and props.Parent or frame
    return inst
end

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(300, 340)
frame.Position = UDim2.fromOffset(20, 120)
frame.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = frame
local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(56,124,255); stroke.Thickness = 1; stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextColor3 = Color3.fromRGB(230,238,255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "  Pulsar.One | AC Emulator"
title.Parent = frame

local scoreLabel = Instance.new("TextLabel")
scoreLabel.Size = UDim2.new(1, -16, 0, 22)
scoreLabel.Position = UDim2.fromOffset(8, 30)
scoreLabel.BackgroundTransparency = 1
scoreLabel.Font = Enum.Font.GothamBold
scoreLabel.TextSize = 12
scoreLabel.TextXAlignment = Enum.TextXAlignment.Left
scoreLabel.TextColor3 = Color3.fromRGB(120, 220, 140)
scoreLabel.Text = "score: 0"
scoreLabel.Parent = frame

local stats = {}
local statNames = { "fps", "stalls", "menu", "shield", "device", "motion" }
for i, name in ipairs(statNames) do
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -16, 0, 18)
    l.Position = UDim2.fromOffset(8, 52 + (i - 1) * 18)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextColor3 = Color3.fromRGB(180, 190, 210)
    l.Text = name .. ": -"
    l.Parent = frame
    stats[name] = l
end

local flagsLabel = Instance.new("TextLabel")
flagsLabel.Size = UDim2.new(1, -16, 0, 90)
flagsLabel.Position = UDim2.fromOffset(8, 168)
flagsLabel.BackgroundTransparency = 1
flagsLabel.Font = Enum.Font.Gotham
flagsLabel.TextSize = 10
flagsLabel.TextXAlignment = Enum.TextXAlignment.Left
flagsLabel.TextYAlignment = Enum.TextYAlignment.Top
flagsLabel.TextWrapped = true
flagsLabel.TextColor3 = Color3.fromRGB(200, 160, 120)
flagsLabel.Text = "flags: none"
flagsLabel.Parent = frame

local resetBtn = Instance.new("TextButton")
resetBtn.Size = UDim2.fromOffset(120, 22)
resetBtn.Position = UDim2.fromOffset(8, 300)
resetBtn.BackgroundColor3 = Color3.fromRGB(28, 38, 56)
resetBtn.BorderSizePixel = 0
resetBtn.Font = Enum.Font.Gotham
resetBtn.TextSize = 11
resetBtn.TextColor3 = Color3.fromRGB(220, 228, 240)
resetBtn.Text = "reset score"
resetBtn.Parent = frame
local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 4); bc.Parent = resetBtn

local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.fromOffset(120, 22)
hideBtn.Position = UDim2.fromOffset(140, 300)
hideBtn.BackgroundColor3 = Color3.fromRGB(28, 38, 56)
hideBtn.BorderSizePixel = 0
hideBtn.Font = Enum.Font.Gotham
hideBtn.TextSize = 11
hideBtn.TextColor3 = Color3.fromRGB(220, 228, 240)
hideBtn.Text = "hide panel"
hideBtn.Parent = frame
local bc2 = Instance.new("UICorner"); bc2.CornerRadius = UDim.new(0, 4); bc2.Parent = hideBtn

-- drag
local dragging, dragStart, basePos = false, nil, nil
title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = UIS:GetMouseLocation()
        basePos = frame.Position
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

local state = {
    score = 0,
    flags = {},
    fps = 0,
    frames = 0,
    lastSample = os.clock(),
    stalls = 0,
    menuSamples = 0,
    menuOpen = 0,
    deviceChanges = 0,
    deviceTimes = {},
    lastDevice = nil,
    motionFlags = 0,
    lowFpsStreak = 0,
    lastFpsFlag = 0,
}

local function addFlag(name, weight)
    state.score = state.score + weight
    state.flags[name] = (state.flags[name] or 0) + 1
end

local function renderFlags()
    local parts = {}
    for name, count in pairs(state.flags) do
        parts[#parts + 1] = name .. " x" .. count
    end
    table.sort(parts)
    flagsLabel.Text = #parts > 0 and ("flags:\n" .. table.concat(parts, "\n")) or "flags: none"
    scoreLabel.Text = string.format("score: %d   %s", state.score,
        state.score >= 100 and "(BAN)" or state.score >= 50 and "(KICK)" or state.score >= 20 and "(WARN)" or "(clean)")
    scoreLabel.TextColor3 = state.score >= 50 and Color3.fromRGB(255,120,120)
        or state.score >= 20 and Color3.fromRGB(255,200,80)
        or Color3.fromRGB(120,220,140)
end

resetBtn.MouseButton1Click:Connect(function()
    state.score = 0; state.flags = {}; state.stalls = 0; state.deviceChanges = 0
    state.motionFlags = 0; state.deviceTimes = {}; state.lastDevice = nil
    state.lowFpsStreak = 0; state.lastFpsFlag = 0
    renderFlags()
end)

hideBtn.MouseButton1Click:Connect(function()
    frame.Visible = not frame.Visible
end)

UIS.InputBegan:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.F8 then
        frame.Visible = not frame.Visible
    end
end)

-- device category switching (mouse+keyboard = same "kbm" category)
if UIS.LastInputTypeChanged then
    UIS.LastInputTypeChanged:Connect(function(t)
        local n = t.Name
        local cat = nil
        if n:find("Touch") then cat = "touch"
        elseif n:find("Gamepad") then cat = "gamepad"
        elseif n:find("Mouse") or n == "Keyboard" then cat = "kbm"
        end
        if not cat then return end
        if state.lastDevice and state.lastDevice ~= cat then
            state.deviceChanges = state.deviceChanges + 1
            local now = os.clock()
            state.deviceTimes[#state.deviceTimes + 1] = now
            while #state.deviceTimes > 0 and now - state.deviceTimes[1] > 10 do
                table.remove(state.deviceTimes, 1)
            end
            if #state.deviceTimes > 5 then addFlag("device_switch", 1) end
        end
        state.lastDevice = cat
    end)
end

local lastMotion = 0
RunService.Heartbeat:Connect(function(dt)
    pcall(function()
        state.frames = state.frames + 1
        local now = os.clock()
        if now - state.lastSample >= 1 then
            state.fps = state.frames / (now - state.lastSample)
            state.frames = 0
            state.lastSample = now
            if state.fps < 25 then
                state.lowFpsStreak = state.lowFpsStreak + 1
            else
                state.lowFpsStreak = 0
            end
            if state.lowFpsStreak >= 5 and (now - state.lastFpsFlag) > 10 then
                state.lastFpsFlag = now
                addFlag("low_fps", 2)
            end
        end

        if dt > 0.5 then
            state.stalls = state.stalls + 1
            addFlag("stall", 3)
        end

        -- ClientShield
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        if ps then
            for _, name in ipairs({ "FustAnimShield", "FustCharSync", "FustShieldGate" }) do
                local s = ps:FindFirstChild(name)
                if s and s:IsA("LocalScript") and not s.Enabled then
                    addFlag("clientshield_off", 10)
                end
            end
        end

        -- MotionSync heuristic: camera yaw vs body yaw while moving
        local cam = workspace.CurrentCamera
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if cam and root and hum and hum.MoveDirection.Magnitude > 0.1 then
            if now - lastMotion > 2 then
                local _, camYaw = cam.CFrame:ToOrientation()
                local _, bodyYaw = root.CFrame:ToOrientation()
                local diff = math.abs((camYaw - bodyYaw + math.pi) % (2 * math.pi) - math.pi)
                if diff > math.rad(60) then
                    state.motionFlags = state.motionFlags + 1
                    addFlag("motion_desync", 1)
                end
                lastMotion = now
            end
        end

        -- menu state (only Fust's own menus; ignore our panels)
        local knownMenus = {
            "FustInventory", "FustCrafting", "FustContainer", "FustSettings", "FustMenu",
            "FustKits", "FustShop", "FustSkins", "FustScrapWheel", "FustCupboard",
            "FustFurnace", "FustRepair", "FustTutorial",
        }
        local open = false
        for _, name in ipairs(knownMenus) do
            local sg = playerGui:FindFirstChild(name)
            if sg and sg:IsA("ScreenGui") and sg.Enabled then
                open = true
                break
            end
        end
        state.menuOpen = open and 1 or 0

        stats.fps.Text = string.format("fps: %.0f", state.fps)
        stats.stalls.Text = "stalls: " .. state.stalls
        stats.menu.Text = "menu open: " .. tostring(open)
        stats.shield.Text = "clientshield: " .. tostring(not state.flags.clientshield_off)
        stats.device.Text = "device switches: " .. state.deviceChanges
        stats.motion.Text = "motion flags: " .. state.motionFlags
        renderFlags()
    end)
end)

renderFlags()
