--[[
    Pulsar.One - FRAMEBREAK [BETA]
    CoreGui menu | INS to hide

    VISUALS : player ESP (boxes / names / health / distance), chams
    COMBAT  : camera aimbot, silent aim, bullet TP (wallbang), rapidfire
    MISC    : status / info

    Silent aim hooks workspace:Raycast. Bullet TP returns the target through walls.
    Rapidfire is an executor mouse1click loop.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local function getGuiParent()
    local parent
    if gethui then
        pcall(function() parent = gethui() end)
    end
    if not parent then
        pcall(function() parent = game:GetService("CoreGui") end)
    end
    if not parent then
        parent = playerGui
    end
    return parent
end

local guiParent = getGuiParent()

local function parentToGui(inst)
    local ok = pcall(function() inst.Parent = guiParent end)
    if not ok or not inst.Parent then
        inst.Parent = playerGui
    end
end

local state = {
    esp = false,
    boxes = true,
    names = true,
    health = true,
    distance = true,
    chams = false,
    teamCheck = false,

    aimbot = false,
    fov = 120,
    smooth = 12,
    targetPart = "Head",

    silent = false,
    bulletTP = false,
    silentFov = 120,

    rapid = false,
    rapidCps = 30,
    rapidMult = 3,

    cornerBoxes = true,
    skeletons = false,
    tracers = false,
    visibilityCheck = false,
    targetHud = false,
}

local lastTarget = nil

-- ============================================================
-- PLAYER HELPERS
-- ============================================================
local function isTeammate(plr)
    if not state.teamCheck then return false end
    return plr.Team ~= nil and LocalPlayer.Team ~= nil and plr.Team == LocalPlayer.Team
end

local function getTargetPart(char)
    if not char then return nil end
    local part = char:FindFirstChild(state.targetPart)
    if part and part:IsA("BasePart") then return part end
    part = char:FindFirstChild("Head")
    if part and part:IsA("BasePart") then return part end
    part = char:FindFirstChild("UpperTorso")
    if part and part:IsA("BasePart") then return part end
    return char:FindFirstChild("HumanoidRootPart")
end

local function findTarget(fovRadius)
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local center = cam.ViewportSize * 0.5
    local best, bestDist = nil, math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isTeammate(plr) then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if char and hum and hum.Health > 0 then
                local part = getTargetPart(char)
                if part then
                    local screen, onScreen = cam:WorldToViewportPoint(part.Position)
                    if screen.Z > 0 then
                        local d = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                        if d <= fovRadius and d < bestDist then
                            bestDist = d
                            best = { player = plr, part = part, position = part.Position }
                        end
                    end
                end
            end
        end
    end

    if best then lastTarget = best end
    return best
end

-- ============================================================
-- VISIBILITY CHECK
-- ============================================================
local function isVisible(head, char)
    local cam = workspace.CurrentCamera
    if not cam or not head then return false end
    local origin = cam.CFrame.Position
    local dir = head.Position - origin
    if dir.Magnitude < 1 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char, LocalPlayer.Character }
    local hit = workspace:Raycast(origin, dir, params)
    if not hit then return true end
    return (hit.Position - head.Position).Magnitude < math.max(head.Size.Magnitude, 1)
end

-- ============================================================
-- ESP / CHAMS
-- ============================================================
local oldEsp = guiParent:FindFirstChild("PulsarFBEsp")
if oldEsp then oldEsp:Destroy() end
local espGui = Instance.new("ScreenGui")
espGui.Name = "PulsarFBEsp"
espGui.ResetOnSpawn = false
espGui.IgnoreGuiInset = true
espGui.DisplayOrder = 998
parentToGui(espGui)

local oldChams = workspace:FindFirstChild("PulsarFBChams")
if oldChams then oldChams:Destroy() end
local chamsFolder = Instance.new("Folder")
chamsFolder.Name = "PulsarFBChams"
chamsFolder.Parent = workspace

local entries = {}

local DrawAPI = _G.Drawing or Drawing
local function makeDrawLine(char, aName, bName, color, thickness)
    local a = char:FindFirstChild(aName)
    local b = char:FindFirstChild(bName)
    if not (a and b) then return nil end
    local l = DrawAPI.new("Line")
    l.Thickness = thickness or 1.5
    l.Visible = false
    l.Color = color or Color3.fromRGB(255, 60, 60)
    return { ln = l, a = a, b = b }
end

local function makeSkeleton(char)
    if not DrawAPI then return nil end
    local s = {}
    local function add(aName, bName, c, t)
        local d = makeDrawLine(char, aName, bName, c, t)
        if d then table.insert(s, d) end
    end
    add("Head", "UpperTorso")
    add("Head", "LowerTorso")
    add("UpperTorso", "LeftUpperArm")
    add("UpperTorso", "RightUpperArm")
    add("LowerTorso", "LeftUpperLeg")
    add("LowerTorso", "RightUpperLeg")
    add("LeftUpperArm", "LeftLowerArm")
    add("RightUpperArm", "RightLowerArm")
    add("LeftUpperLeg", "LeftLowerLeg")
    add("RightUpperLeg", "RightLowerLeg")
    add("LeftLowerArm", "LeftHand")
    add("RightLowerArm", "RightHand")
    add("LeftLowerLeg", "LeftFoot")
    add("RightLowerLeg", "RightFoot")
    return s
end

local function destroySkeleton(entry)
    if entry.skel then
        for _, d in ipairs(entry.skel) do
            pcall(function() d.ln:Remove() end)
        end
        entry.skel = nil
    end
    if entry.tracer then
        pcall(function() entry.tracer.ln:Remove() end)
        entry.tracer = nil
    end
end

local function makeLabel(plr, head)
    local bg = Instance.new("BillboardGui")
    bg.Name = "PulsarFBLabel"
    bg.Adornee = head
    bg.Size = UDim2.fromOffset(210, 40)
    bg.StudsOffset = Vector3.new(0, 2.4, 0)
    bg.AlwaysOnTop = true
    bg.MaxDistance = 1500
    bg.Parent = espGui

    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(240, 240, 245)
    label.TextStrokeTransparency = 0.25
    label.Text = plr.Name
    label.Parent = bg

    return bg, label
end

local function makeBox()
    local box = Instance.new("Frame")
    box.Name = "PulsarFBBox"
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Visible = false
    box.ZIndex = 5
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 65, 65)
    stroke.Thickness = 1.5
    stroke.Parent = box

    -- health bar
    local hpBack = Instance.new("Frame")
    hpBack.Name = "HpBack"
    hpBack.Position = UDim2.new(0, 2, 0, -6)
    hpBack.Size = UDim2.new(1, -4, 0, 4)
    hpBack.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    hpBack.BackgroundTransparency = 0.35
    hpBack.BorderSizePixel = 0
    hpBack.Parent = box
    local foo = Instance.new("UICorner", hpBack); foo.CornerRadius = UDim.new(1, 0)
    local hpFill = Instance.new("Frame")
    hpFill.Name = "HpFill"
    hpFill.Position = UDim2.fromScale(0, 0)
    hpFill.Size = UDim2.fromScale(1, 1)
    hpFill.BackgroundColor3 = Color3.fromRGB(90, 220, 150)
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBack
    local bar = Instance.new("UICorner", hpFill); bar.CornerRadius = UDim.new(1, 0)

    -- corner accents
    local corners = Instance.new("Frame")
    corners.Name = "Corners"
    corners.Position = UDim2.fromScale(0, 0)
    corners.Size = UDim2.fromScale(1, 1)
    corners.BackgroundTransparency = 1
    corners.BorderSizePixel = 0
    corners.Parent = box
    for i = 1, 4 do
        local h = Instance.new("Frame")
        h.Name = "c" .. i
        h.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        h.BorderSizePixel = 0
        h.Size = UDim2.fromOffset(8, 1)
        h.Parent = corners
        local v = Instance.new("Frame")
        v.Name = "v" .. i
        v.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        v.BorderSizePixel = 0
        v.Size = UDim2.fromOffset(1, 8)
        v.Parent = corners
    end
    -- position corners in RenderStepped because they depend on box size; do it here once per update.
    box.Parent = espGui
    return box
end

local function removeEntry(entry)
    if entry.box then pcall(function() entry.box:Destroy() end) end
    if entry.label then pcall(function() entry.label:Destroy() end) end
    if entry.highlight then pcall(function() entry.highlight:Destroy() end) end
    destroySkeleton(entry)
    entry.box, entry.label, entry.highlight, entry.char = nil, nil, nil, nil
end

local function syncEsp()
    local seen = {}

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isTeammate(plr) then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if char and hum and hum.Health > 0 then
                seen[plr] = true
                local entry = entries[plr]
                if not entry then
                    entry = {}
                    entries[plr] = entry
                end

                if entry.char ~= char then
                    removeEntry(entry)
                    entry.char = char
                end

                -- chams
                if state.chams then
                    if not entry.highlight or not entry.highlight.Parent then
                        local h = Instance.new("Highlight")
                        h.Name = "PulsarFBCham"
                        h.Adornee = char
                        h.FillColor = Color3.fromRGB(255, 60, 60)
                        h.OutlineColor = Color3.fromRGB(255, 255, 255)
                        h.FillTransparency = 0.55
                        h.OutlineTransparency = 0
                        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        h.Parent = chamsFolder
                        entry.highlight = h
                    end
                    entry.highlight.Adornee = char
                elseif entry.highlight then
                    pcall(function() entry.highlight:Destroy() end)
                    entry.highlight = nil
                end

                -- box
                if state.esp and state.boxes then
                    if not entry.box or not entry.box.Parent then
                        entry.box = makeBox()
                    end
                elseif entry.box then
                    pcall(function() entry.box:Destroy() end)
                    entry.box = nil
                end

                -- skeleton / tracer
                if state.esp and state.skeletons and DrawAPI then
                    if not entry.skel then
                        entry.skel = makeSkeleton(char)
                    end
                elseif entry.skel then
                    destroySkeleton(entry)
                end
                if state.esp and state.tracers and DrawAPI and entry.char.Parent then
                    if not entry.tracer then
                        local head = entry.char:FindFirstChild("Head") or entry.char:FindFirstChild("HumanoidRootPart")
                        if head then
                            local l = DrawAPI.new("Line")
                            l.Thickness = 1.5
                            l.Visible = false
                            l.Color = Color3.fromRGB(255, 60, 60)
                            entry.tracer = { ln = l, a = head }
                        end
                    end
                elseif entry.tracer then
                    destroySkeleton(entry)
                end

                -- label
                local wantLabel = state.esp and (state.names or state.health or state.distance)
                if wantLabel then
                    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
                    if head then
                        if not entry.label or not entry.label.Parent or entry.label.Adornee ~= head then
                            if entry.label then pcall(function() entry.label:Destroy() end) end
                            entry.label, entry.labelText = makeLabel(plr, head)
                        end
                        local parts = {}
                        if state.names then table.insert(parts, plr.Name) end
                        if state.health then table.insert(parts, string.format("HP %d", math.floor(hum.Health))) end
                        if state.distance then
                            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            local myPos = root and root.Position or workspace.CurrentCamera.CFrame.Position
                            table.insert(parts, string.format("%dm", math.floor((head.Position - myPos).Magnitude)))
                        end
                        if #parts == 0 then parts = { plr.Name } end
                        entry.labelText.Text = table.concat(parts, " | ")
                    end
                elseif entry.label then
                    pcall(function() entry.label:Destroy() end)
                    entry.label, entry.labelText = nil, nil
                end
            end
        end
    end

    for plr, entry in pairs(entries) do
        if not seen[plr] then
            removeEntry(entry)
            entries[plr] = nil
        end
    end
end

local function updateBoxes()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize

    local function updateSkeleton(entry)
        if not (entry.skel and DrawAPI) then return end
        for _, d in ipairs(entry.skel) do
            if d.a.Parent and d.b.Parent then
                local p = cam:WorldToViewportPoint(d.a.Position)
                local q = cam:WorldToViewportPoint(d.b.Position)
                if p.Z > 0 and q.Z > 0 then
                    d.ln.From = Vector2.new(p.X, p.Y)
                    d.ln.To = Vector2.new(q.X, q.Y)
                    d.ln.Visible = true
                else
                    d.ln.Visible = false
                end
            else
                d.ln.Visible = false
            end
        end
    end

    local function updateTracer(entry)
        if not (entry.tracer and DrawAPI) then return end
        local head = entry.tracer.a
        if not head or not head.Parent then
            entry.tracer.ln.Visible = false
            return
        end
        local p = cam:WorldToViewportPoint(head.Position)
        if p.Z > 0 then
            entry.tracer.ln.From = Vector2.new(vp.X * 0.5, vp.Y - 8)
            entry.tracer.ln.To = Vector2.new(p.X, p.Y)
            entry.tracer.ln.Visible = true
        else
            entry.tracer.ln.Visible = false
        end
    end

    local function refreshCorners(box, on)
        local corners = box:FindFirstChild("Corners")
        if not corners then return end
        if not on then corners.Visible = false return end
        corners.Visible = true
        local w, h = box.AbsoluteSize.X, box.AbsoluteSize.Y
        local pts = {
            { 0, 0 }, { w - 8, 0 },
            { 0, h - 1 }, { w - 8, h - 1 },
        }
        for i = 1, 4 do
            local f = corners:FindFirstChild("c" .. i)
            if f then f.Position = UDim2.fromOffset(math.floor(pts[i][1]), math.floor(pts[i][2])) end
            local v = corners:FindFirstChild("v" .. i)
            if v then v.Position = UDim2.fromOffset(math.floor(pts[i][1]), math.floor(pts[i][2])) end
        end
    end

    for plr, entry in pairs(entries) do
        if entry.skel and (not state.esp or not state.skeletons) then
            destroySkeleton(entry)
        end
        if entry.tracer and (not state.esp or not state.tracers) then
            destroySkeleton(entry)
        end

        local box = entry.box
        local char = entry.char
        if char and char.Parent then
            local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
            if head and (not state.visibilityCheck or isVisible(head, char)) then
                updateSkeleton(entry)
                updateTracer(entry)
            else
                updateSkeleton(entry)
                updateTracer(entry)
            end
        end

        if box and char and char.Parent and state.esp and state.boxes then
            local ok, cf, size = pcall(function() return char:GetBoundingBox() end)
            if ok and typeof(cf) == "CFrame" and typeof(size) == "Vector3" and size.Magnitude > 0.1 then
                local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
                local corners = {
                    cf * Vector3.new(-hx, -hy, -hz), cf * Vector3.new(-hx, -hy, hz),
                    cf * Vector3.new(-hx, hy, -hz), cf * Vector3.new(-hx, hy, hz),
                    cf * Vector3.new(hx, -hy, -hz), cf * Vector3.new(hx, -hy, hz),
                    cf * Vector3.new(hx, hy, -hz), cf * Vector3.new(hx, hy, hz),
                }
                local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
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
                    refreshCorners(box, state.cornerBoxes)
                    box.Visible = true
                else
                    box.Visible = false
                end
            else
                box.Visible = false
            end
        elseif box then
            box.Visible = false
        end
    end
end

-- ============================================================
-- FOV CIRCLE
-- ============================================================
local oldOverlay = guiParent:FindFirstChild("PulsarFBOverlay")
if oldOverlay then oldOverlay:Destroy() end
local overlayGui = Instance.new("ScreenGui")
overlayGui.Name = "PulsarFBOverlay"
overlayGui.ResetOnSpawn = false
overlayGui.IgnoreGuiInset = true
overlayGui.DisplayOrder = 999
parentToGui(overlayGui)

local fovCircle = Instance.new("Frame")
fovCircle.Name = "FOV"
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.fromScale(0.5, 0.5)
fovCircle.BackgroundTransparency = 1
fovCircle.BorderSizePixel = 0
fovCircle.Visible = false
fovCircle.ZIndex = 2
fovCircle.Parent = overlayGui
local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovCircle
local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(72, 132, 255)
fovStroke.Thickness = 1
fovStroke.Transparency = 0.25
fovStroke.Parent = fovCircle

-- ============================================================
-- TARGET HUD
-- ============================================================
local oldHud = guiParent:FindFirstChild("PulsarFBTargetHud")
if oldHud then oldHud:Destroy() end
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "PulsarFBTargetHud"
hudGui.ResetOnSpawn = false
hudGui.IgnoreGuiInset = true
hudGui.DisplayOrder = 996
parentToGui(hudGui)

local hudFrame = Instance.new("Frame")
hudFrame.Name = "Target"
hudFrame.AnchorPoint = Vector2.new(1, 0)
hudFrame.Position = UDim2.new(1, -18, 0, 18)
hudFrame.Size = UDim2.fromOffset(250, 108)
hudFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
hudFrame.BackgroundTransparency = 0.12
hudFrame.BorderSizePixel = 0
hudFrame.Visible = false
local hudCorner = Instance.new("UICorner", hudFrame); hudCorner.CornerRadius = UDim.new(0, 12)
local hudStroke = Instance.new("UIStroke", hudFrame); hudStroke.Color = Color3.fromRGB(255, 70, 70); hudStroke.Thickness = 1
hudFrame.Parent = hudGui

local hudTitle = Instance.new("TextLabel", hudFrame)
hudTitle.Name = "Title"
hudTitle.Position = UDim2.fromOffset(12, 6)
hudTitle.Size = UDim2.new(1, -24, 0, 14)
hudTitle.BackgroundTransparency = 1
hudTitle.Font = Enum.Font.GothamBold
hudTitle.TextSize = 11
hudTitle.TextColor3 = Color3.fromRGB(255, 65, 65)
hudTitle.TextXAlignment = Enum.TextXAlignment.Left
hudTitle.Text = "TARGET"

local hudName = Instance.new("TextLabel", hudFrame)
hudName.Name = "Name"
hudName.Position = UDim2.fromOffset(12, 24)
hudName.Size = UDim2.new(1, -24, 0, 18)
hudName.BackgroundTransparency = 1
hudName.Font = Enum.Font.GothamBold
hudName.TextSize = 14
hudName.TextColor3 = Color3.fromRGB(236, 236, 244)
hudName.TextXAlignment = Enum.TextXAlignment.Left
hudName.Text = ""

local hudHpBack = Instance.new("Frame", hudFrame)
hudHpBack.Name = "HpBack"
hudHpBack.Position = UDim2.fromOffset(12, 48)
hudHpBack.Size = UDim2.new(1, -24, 0, 10)
hudHpBack.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
hudHpBack.BackgroundTransparency = 0.2
hudHpBack.BorderSizePixel = 0
hudHpBack.Parent = hudFrame
local hdfc = Instance.new("UICorner", hudHpBack); hdfc.CornerRadius = UDim.new(1, 0)
local hudHpFill = Instance.new("Frame", hudHpBack)
hudHpFill.Name = "Fill"
hudHpFill.Position = UDim2.fromScale(0, 0)
hudHpFill.Size = UDim2.fromScale(1, 1)
hudHpFill.BackgroundColor3 = Color3.fromRGB(90, 220, 150)
hudHpFill.BorderSizePixel = 0
hudHpFill.Parent = hudHpBack
local hfc = Instance.new("UICorner", hudHpFill); hfc.CornerRadius = UDim.new(1, 0)

local hudHpText = Instance.new("TextLabel", hudFrame)
hudHpText.Name = "HpText"
hudHpText.Position = UDim2.fromOffset(12, 60)
hudHpText.Size = UDim2.new(1, -24, 0, 14)
hudHpText.BackgroundTransparency = 1
hudHpText.Font = Enum.Font.Gotham
hudHpText.TextSize = 10
hudHpText.TextColor3 = Color3.fromRGB(150, 160, 180)
hudHpText.TextXAlignment = Enum.TextXAlignment.Left
hudHpText.Text = ""

local hudInfo = Instance.new("TextLabel", hudFrame)
hudInfo.Name = "Info"
hudInfo.Position = UDim2.fromOffset(12, 80)
hudInfo.Size = UDim2.new(1, -24, 0, 14)
hudInfo.BackgroundTransparency = 1
hudInfo.Font = Enum.Font.Gotham
hudInfo.TextSize = 10
hudInfo.TextColor3 = Color3.fromRGB(150, 160, 180)
hudInfo.TextXAlignment = Enum.TextXAlignment.Left
hudInfo.Text = ""

local function updateTargetHud()
    if not state.targetHud then
        hudFrame.Visible = false
        return
    end
    local player = lastTarget and lastTarget.player
    local char = player and player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not player or not char or not hum or hum.Health <= 0 or not root then
        hudFrame.Visible = false
        return
    end
    hudFrame.Visible = true
    hudName.Text = player.Name

    local ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
    if ratio < 0.3 then
        hudHpFill.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
    elseif ratio < 0.6 then
        hudHpFill.BackgroundColor3 = Color3.fromRGB(255, 180, 60)
    else
        hudHpFill.BackgroundColor3 = Color3.fromRGB(90, 220, 150)
    end
    hudHpFill.Size = UDim2.fromScale(ratio, 1)
    hudHpText.Text = string.format("HP %d / %d", math.floor(hum.Health), math.floor(hum.MaxHealth))

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local camPos = workspace.CurrentCamera.CFrame.Position
    local myPos = myRoot and myRoot.Position or camPos
    local dist = math.floor((root.Position - myPos).Magnitude)
    hudInfo.Text = string.format("%dm  •  %s", dist, state.targetPart)
end

-- ============================================================
-- SILENT AIM
-- ============================================================
local silentHooked = false

local function syntheticHit(target, origin)
    local dir = target.position - origin
    return {
        Instance = target.part,
        Position = target.position,
        Normal = -dir.Unit,
        Distance = dir.Magnitude,
        Material = Enum.Material.Plastic,
        Hit = true,
    }
end

local silentPrev = getgenv().pulsarFBSilent
if silentPrev then
    pcall(function()
        if silentPrev.kind == "namecall" then
            setreadonly(silentPrev.mt, false)
            rawset(silentPrev.mt, "__namecall", silentPrev.old)
            setreadonly(silentPrev.mt, true)
        elseif silentPrev.kind == "hookfunction" and hookfunction then
            hookfunction(silentPrev.hooked, silentPrev.old)
        end
    end)
    getgenv().pulsarFBSilent = nil
end

local function installSilent()
    if silentHooked then return end
    if not (getrawmetatable and newcclosure and getnamecallmethod and setreadonly) then return end

    local okMt, mt = pcall(getrawmetatable, game)
    if not okMt or not mt then return end
    local oldNamecall = mt.__namecall
    if not oldNamecall then return end

    local installed = pcall(function()
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "Raycast" and self == workspace and state.silent then
                local origin, direction, params = ...
                if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                    local firing = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                    if firing then
                        local target = findTarget(state.silentFov)
                        if target then
                            local dir = target.position - origin
                            if state.bulletTP then
                                return syntheticHit(target, origin)
                            end
                            local result = oldNamecall(self, origin, dir, params)
                            if result and result.Instance == target.part then
                                return result
                            end
                            return oldNamecall(self, origin, direction, params)
                        end
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
    end)

    if installed then
        getgenv().pulsarFBSilent = { kind = "namecall", mt = mt, old = oldNamecall }
        silentHooked = true
    end
end

installSilent()

-- ============================================================
-- AIMBOT / FOV / RAPIDFIRE LOOPS
-- ============================================================
RunService:BindToRenderStep("PulsarFBAim", Enum.RenderPriority.Camera.Value + 10, function(dt)
    if state.aimbot and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = findTarget(state.fov)
        if target then
            local cam = workspace.CurrentCamera
            local goal = CFrame.lookAt(cam.CFrame.Position, target.position)
            local alpha = 1 - math.exp(-dt * (10 / math.max(state.smooth, 1)))
            cam.CFrame = cam.CFrame:Lerp(goal, alpha)
        end
    end
end)

local VIM = game:GetService("VirtualInputManager")
local function fireClick()
    local ok = pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
    if not ok then
        pcall(function() mouse1click() end)
    end
end

-- rapidfire via WeaponController.update dt scale (true rate multiplier, no mouse spam)
local rapidControllers = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Controllers")
local WeaponController = nil
pcall(function()
    local wc = rapidControllers:FindFirstChild("WeaponController")
    if wc then
        local ok, module = pcall(require, wc)
        if ok and type(module) == "table" then
            WeaponController = module
        end
    end
end)

local rapidPrev = getgenv().pulsarFBRapid
if rapidPrev and typeof(rapidPrev) == "table" then
    pcall(function()
        if rapidPrev.owner == WeaponController then
            WeaponController.update = rapidPrev.original
        end
    end)
end
getgenv().pulsarFBRapid = nil

if WeaponController and type(WeaponController.update) == "function" then
    local oldUpdate = WeaponController.update
    local newUpdate = newcclosure(function(dt)
        local mult = 1
        if state.rapid and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            mult = math.max(state.rapidMult or 3, 1)
        end
        if mult ~= 1 then
            dt = dt * mult
        end
        return oldUpdate(dt)
    end)
    pcall(function()
        WeaponController.update = newUpdate
        getgenv().pulsarFBRapid = { owner = WeaponController, original = oldUpdate }
    end)
end

RunService.RenderStepped:Connect(function()
    pcall(function()
        local radius = 0
        if state.aimbot then radius = state.fov
        elseif state.silent then radius = state.silentFov end
        if radius > 0 then
            fovCircle.Size = UDim2.fromOffset(radius * 2, radius * 2)
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end

        if state.targetHud then
            local hudTarget = lastTarget and lastTarget.player and lastTarget.player.Parent and lastTarget
            if not hudTarget then
                local t = findTarget(math.max(state.fov, 260))
                if t then lastTarget = t end
            end
        end
        updateTargetHud()

        updateBoxes()
    end)
end)

task.spawn(function()
    while true do
        pcall(syncEsp)
        task.wait(0.25)
    end
end)

-- ============================================================
-- UI
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
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local oldMenu = guiParent:FindFirstChild("PulsarFrameBreak")
if oldMenu then oldMenu:Destroy() end

local gui = new("ScreenGui", {
    Name = "PulsarFrameBreak",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 1000,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, nil)
parentToGui(gui)

local cam = workspace.CurrentCamera or workspace:WaitForChild("CurrentCamera")
local vp = cam.ViewportSize
local WIN_W, WIN_H = 640, 460

local win = new("Frame", {
    Size = UDim2.fromOffset(WIN_W, WIN_H),
    Position = UDim2.fromOffset(math.floor((vp.X - WIN_W) / 2), math.floor((vp.Y - WIN_H) / 2)),
    BackgroundColor3 = BG,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 16) }, win)
new("UIStroke", { Color = BORDER, Thickness = 1 }, win)

local uiScale = new("UIScale", {}, win)
local function fitScale()
    local size = cam.ViewportSize
    uiScale.Scale = math.clamp(math.min(1, (size.X - 40) / WIN_W, (size.Y - 40) / WIN_H), 0.6, 1)
end
fitScale()
cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() pcall(fitScale) end)

new("Frame", {
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = ACCENT,
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
}, win)

local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 56),
    BackgroundTransparency = 1,
    Active = true,
}, win)

local logoDot = new("Frame", {
    Position = UDim2.fromOffset(20, 20),
    Size = UDim2.fromOffset(6, 6),
    BackgroundColor3 = ACCENT,
    BorderSizePixel = 0,
}, header)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, logoDot)

new("TextLabel", {
    Position = UDim2.fromOffset(32, 12),
    Size = UDim2.new(0, 260, 0, 22),
    BackgroundTransparency = 1,
    Font = FONT_BOLD,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    RichText = true,
    Text = '<font color="#ffffff">PULSAR</font><font color="#4884ff">.ONE</font>',
}, header)

new("TextLabel", {
    Position = UDim2.fromOffset(34, 34),
    Size = UDim2.new(0, 300, 0, 14),
    BackgroundTransparency = 1,
    Font = FONT_MED,
    TextSize = 9,
    TextColor3 = LABEL,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "FRAMEBREAK [BETA]",
}, header)

local close = new("TextButton", {
    Position = UDim2.new(1, -36, 0, 14),
    Size = UDim2.fromOffset(22, 22),
    BackgroundTransparency = 1,
    Font = FONT_MED,
    TextSize = 18,
    TextColor3 = MUTED,
    Text = "x",
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
        local size = cam.ViewportSize
        local nx = math.clamp(startPos.X.Offset + delta.X, 8, math.max(8, size.X - win.AbsoluteSize.X - 8))
        local ny = math.clamp(startPos.Y.Offset + delta.Y, 8, math.max(8, size.Y - win.AbsoluteSize.Y - 8))
        win.Position = UDim2.fromOffset(nx, ny)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragStart = nil
    end
end)

local nav = new("Frame", {
    Position = UDim2.fromOffset(18, 58),
    Size = UDim2.new(1, -36, 0, 32),
    BackgroundTransparency = 1,
}, win)
new("Frame", {
    Position = UDim2.new(0, 0, 0, 31),
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = BORDER,
    BackgroundTransparency = 0.25,
    BorderSizePixel = 0,
}, nav)

local tabOrder = { "visuals", "combat", "misc" }
local tabLabels = { "VISUALS", "COMBAT", "MISC" }
local tabButtons, tabFrames, tabUnderlines = {}, {}, {}
local activeTab = "visuals"

local content = new("Frame", {
    Position = UDim2.fromOffset(16, 96),
    Size = UDim2.new(1, -32, 1, -142),
    BackgroundTransparency = 1,
}, win)

local function makeTab(name)
    local f = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = (name == activeTab),
    }, content)
    tabFrames[name] = f
    return f
end

local function switchTab(name)
    activeTab = name
    for k, f in pairs(tabFrames) do f.Visible = (k == name) end
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
    }, nav)
    local ul = new("Frame", {
        Position = UDim2.fromOffset(0, 29),
        Size = UDim2.fromOffset(28, 2),
        BackgroundColor3 = ACCENT,
        BorderSizePixel = 0,
        Visible = (name == activeTab),
    }, b)
    tabUnderlines[name] = ul
    b.MouseButton1Click:Connect(function() switchTab(name) end)
    tabButtons[name] = b
end

local visualsTab = makeTab("visuals")
local combatTab = makeTab("combat")
local miscTab = makeTab("misc")

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
    }, parent)
    new("UICorner", { CornerRadius = UDim.new(0, 12) }, p)
    new("UIStroke", { Color = BORDER, Thickness = 1 }, p)
    new("TextLabel", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 0, 30),
        BackgroundTransparency = 1,
        Font = FONT_BOLD,
        TextSize = 11,
        TextColor3 = ACCENT,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = title,
    }, p)
    new("Frame", {
        Position = UDim2.fromOffset(0, 29),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = ACCENT,
        BackgroundTransparency = 0.72,
        BorderSizePixel = 0,
    }, p)
    return new("Frame", {
        Position = UDim2.fromOffset(10, 38),
        Size = UDim2.new(1, -20, 1, -46),
        BackgroundTransparency = 1,
    }, p)
end

local function makeToggle(parent, key, label, y)
    local row = new("TextButton", {
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, parent)
    local lab = new("TextLabel", {
        Size = UDim2.new(1, -56, 1, 0),
        BackgroundTransparency = 1,
        Font = FONT,
        TextSize = 11,
        TextColor3 = LABEL,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = label,
    }, row)
    local pill = new("Frame", {
        Position = UDim2.new(1, -38, 0, 5),
        Size = UDim2.fromOffset(34, 18),
        BackgroundColor3 = PANEL2,
        BorderSizePixel = 0,
    }, row)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
    local knob = new("Frame", {
        Position = UDim2.fromOffset(2, 2),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = TEXT,
        BorderSizePixel = 0,
    }, pill)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

    local function apply(on)
        state[key] = on
        pill.BackgroundColor3 = on and ACCENT or PANEL2
        lab.TextColor3 = on and TEXT or LABEL
        knob.Position = UDim2.fromOffset(on and 18 or 2, 2)
    end
    row.MouseButton1Click:Connect(function()
        apply(not state[key])
    end)
    toggleWidgets[key] = { apply = apply }
    apply(state[key])
end

local function makeSlider(parent, key, label, minimum, maximum, step, y, fmt)
    local row = new("Frame", {
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
    }, parent)
    new("TextLabel", {
        Size = UDim2.new(1, -60, 0, 16),
        BackgroundTransparency = 1,
        Font = FONT,
        TextSize = 11,
        TextColor3 = LABEL,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = label,
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
    }, row)
    local track = new("Frame", {
        Position = UDim2.fromOffset(0, 22),
        Size = UDim2.new(1, 0, 0, 4),
        BackgroundColor3 = PANEL2,
        BorderSizePixel = 0,
    }, row)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = ACCENT,
        BorderSizePixel = 0,
    }, track)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(10, 10),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = TEXT,
        BorderSizePixel = 0,
    }, track)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
    local hit = new("TextButton", {
        Position = UDim2.fromOffset(0, 13),
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = "",
    }, row)

    local function setValue(v)
        v = math.clamp(v, minimum, maximum)
        if step and step > 0 then v = math.floor(v / step + 0.5) * step end
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
            local moveConn, endConn
            moveConn = UIS.InputChanged:Connect(function(m)
                if m.UserInputType == Enum.UserInputType.MouseMovement or m.UserInputType == Enum.UserInputType.Touch then seek(m) end
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
    }, parent)
    new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
    b.MouseEnter:Connect(function() b.BackgroundColor3 = Color3.fromRGB(44, 47, 62) end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = PANEL2 end)
    if callback then b.MouseButton1Click:Connect(callback) end
    return b
end

-- VISUALS
local espPanel = makePanel(visualsTab, "PLAYER ESP", 0, 0, 308, 240)
makeToggle(espPanel, "esp", "Enable ESP", 0)
makeToggle(espPanel, "boxes", "Boxes", 28)
makeToggle(espPanel, "names", "Names", 56)
makeToggle(espPanel, "health", "Health", 84)
makeToggle(espPanel, "distance", "Distance", 112)
makeToggle(espPanel, "skeletons", "Skeleton", 140)
makeToggle(espPanel, "tracers", "Tracers", 168)

local chamsPanel = makePanel(visualsTab, "EXTRA", 320, 0, 308, 240)
makeToggle(chamsPanel, "cornerBoxes", "Corner boxes", 0)
makeToggle(chamsPanel, "visibilityCheck", "Visibility check", 28)
makeToggle(chamsPanel, "chams", "Chams", 56)
makeToggle(chamsPanel, "teamCheck", "Team check", 84)
makeInfo(chamsPanel, 112, 100, "Corner boxes, skeletons, tracers and chams are all client-side.\nVisibility check only draws players you can see.")

local targetPanel = makePanel(visualsTab, "TARGET HUD", 0, 252, 308, 70)
makeToggle(targetPanel, "targetHud", "Enable target HUD", 0)

local visualStatus = makePanel(visualsTab, "STATUS", 320, 252, 308, 70)
local visualStatusLabel = makeInfo(visualStatus, 0, 20, "players: 0 | target: none")
table.insert(statusLabels, visualStatusLabel)

-- COMBAT
local aimPanel = makePanel(combatTab, "AIMBOT", 0, 0, 308, 200)
makeToggle(aimPanel, "aimbot", "Enable aimbot", 0)
makeSlider(aimPanel, "fov", "FOV", 20, 600, 5, 32, "%.0f")
makeSlider(aimPanel, "smooth", "Smooth", 1, 30, 1, 72, "%.0f")
local targetBtn = makeButton(aimPanel, "Target: Head", 112, nil)
makeInfo(aimPanel, 138, 16, "Hold RMB to aim.")
targetBtn.MouseButton1Click:Connect(function()
    local parts = { "Head", "UpperTorso", "HumanoidRootPart" }
    local idx = 1
    for i, p in ipairs(parts) do if p == state.targetPart then idx = i; break end end
    state.targetPart = parts[idx % #parts + 1]
    targetBtn.Text = "Target: " .. state.targetPart
end)

local silentPanel = makePanel(combatTab, "SILENT AIM", 320, 0, 308, 200)
makeToggle(silentPanel, "silent", "Enable silent aim", 0)
makeToggle(silentPanel, "bulletTP", "Bullet TP (wallbang)", 28)
makeSlider(silentPanel, "silentFov", "FOV", 20, 600, 5, 64, "%.0f")
makeInfo(silentPanel, 104, 50, "Hooks workspace:Raycast while firing. Bullet TP ignores walls.")

local rapidPanel = makePanel(combatTab, "RAPIDFIRE", 0, 212, 628, 116)
makeToggle(rapidPanel, "rapid", "Enable rapidfire", 0)
makeSlider(rapidPanel, "rapidMult", "Fire rate mult", 1, 20, 0.5, 32, "x%.1f")

-- MISC
local infoPanel = makePanel(miscTab, "INFO", 0, 0, 628, 200)
makeInfo(infoPanel, 0, 120, "FRAMEBREAK [BETA] - Pulsar.One\n\nINS hides the menu.\nDo not fire admin/money remotes (AdminCommand, Net.SetWalkSpeed, Net.GodMode, AdminRemotes.GiveMoney) - they are honeypots.\n\nSilent aim / rapidfire may be logged by AimTraceSender / ClientGuard. Use at your own risk.")

local miscStatus = makePanel(miscTab, "STATUS", 0, 212, 628, 116)
local miscStatusLabel = makeInfo(miscStatus, 0, 70, "players: 0 | target: none")
table.insert(statusLabels, miscStatusLabel)

-- FOOTER
local footer = new("Frame", {
    Position = UDim2.new(0, 0, 1, -34),
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundTransparency = 1,
}, win)
new("Frame", {
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = BORDER,
    BackgroundTransparency = 0.25,
    BorderSizePixel = 0,
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
    Text = "Pulsar.One | INS",
}, footer)

local function refreshStatus()
    local targetName = lastTarget and lastTarget.player and lastTarget.player.Name or "none"
    local text = string.format("players: %d | target: %s", #Players:GetPlayers(), targetName)
    for _, label in ipairs(statusLabels) do
        if label.Parent then label.Text = text end
    end
    footRight.Text = string.format("FOV %d | INS", state.aimbot and state.fov or state.silentFov)
end

task.spawn(function()
    while true do
        pcall(refreshStatus)
        task.wait(0.25)
    end
end)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Insert then
        win.Visible = not win.Visible
    end
end)

refreshStatus()
