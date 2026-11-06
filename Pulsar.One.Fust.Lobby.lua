--[[
    Pulsar.One - Fust lobby stage
    Executing this anywhere except the lobby is refused.
    Click the card -> queued -> joins server -> Preload.lua runs -> main loads.
]]
local REPO = "https://raw.githubusercontent.com/AddMeOnDiscordForHelp/Random-Scripts/main/"
local PRELOAD = "Pulsar.One.Fust.Preload.lua"

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local request = request or http_request
local messagebox = messageboxasync or messagebox
local queueOnTeleport = queue_on_teleport or queueonteleport or queueteleport

local function notify(text)
    if type(messagebox) == "function" then pcall(messagebox, text, "Pulsar.One", 48) end
end

local function safeRequest(url)
    if type(request) ~= "function" then return nil end
    local ok, res = pcall(request, { Url = url, Method = "GET" })
    if not ok or type(res) ~= "table" then return nil end
    if type(res.Body) ~= "string" or res.StatusCode ~= 200 then return nil end
    return res.Body
end

local function isLobby()
    if not LocalPlayer.Character then return true end
    local worldAttr = nil
    pcall(function() worldAttr = workspace:GetAttribute("FustWorld") end)
    if worldAttr == false then return true end
    local ok, pg = pcall(function() return LocalPlayer:FindFirstChild("PlayerGui") end)
    if ok and pg then
        local menu = pg:FindFirstChild("FustMenu")
        local root = menu and menu:FindFirstChild("Root")
        if root and root:IsA("GuiObject") and root.Visible then return true end
    end
    return false
end

local inLobby = isLobby()
if not inLobby then
    notify("Run this in the lobby (before spawning) or use Pulsar.One.Fust.InGame.lua after spawn.")
    return
end

if type(queueOnTeleport) ~= "function" then
    notify("Your executor has no queue_on_teleport.\n\nJoin a server, then run:\nloadstring(request({Url='" .. REPO .. "InGame.lua',Method='GET'}).Body)();")
    return
end

local queueScript = function()
    local src = safeRequest(REPO .. PRELOAD)
    if not src then notify("Failed to fetch " .. PRELOAD) return end
    local fn, err = loadstring(src)
    if type(fn) ~= "function" then notify("Failed to load " .. PRELOAD .. "\n" .. tostring(err)) return end
    queueOnTeleport(string.format("loadstring(%q)();", src))
end

-- drawing card
local ok = pcall(function()
    local uis = game:GetService("UserInputService")
    local new = Drawing.new
    local v2 = Vector2.new
    local C = {
        line = Color3.fromRGB(18, 26, 44), bg = Color3.fromRGB(12, 16, 24),
        text = Color3.fromRGB(232, 238, 255), dim = Color3.fromRGB(120, 134, 158),
        accent = Color3.fromRGB(56, 124, 255), btn = Color3.fromRGB(22, 30, 44),
        hover = Color3.fromRGB(30, 42, 62), press = Color3.fromRGB(16, 22, 32),
    }
    local size = v2(250, 100)
    local vp = workspace.CurrentCamera.ViewportSize
    local origin = v2(math.floor(vp.X * 0.72), math.floor(vp.Y * 0.42))
    local objs, lines = {}, {}

    local function rect(pos, sz, color, z)
        local d = new("Square")
        d.Position, d.Size, d.Color, d.ZIndex = pos, sz, color, z
        d.Filled, d.Visible = true, true
        table.insert(objs, d)
        return d
    end
    local function label(text, pos, sz, color)
        local d = new("Text")
        d.Text, d.Position, d.Size = text, pos, sz
        d.Color, d.ZIndex, d.Visible = color or C.text, 6, true
        table.insert(objs, d)
        return d
    end
    local function line(a, b)
        local d = new("Line")
        d.From, d.To, d.Color = a, b, C.text
        d.Thickness, d.ZIndex, d.Visible = 2, 6, true
        table.insert(lines, d)
        return d
    end

    rect(origin - v2(1, 1), size + v2(2, 2), C.line, 1)
    rect(origin, size, C.bg, 2)
    local brand = label("Pulsar", origin + v2(14, 12), 16)
    label(".One", brand.Position + v2(brand.TextBounds.X, 0), 16, C.accent)

    local dot = new("Circle")
    dot.Position = origin + v2(18, 44)
    dot.Radius, dot.Filled, dot.Color, dot.ZIndex, dot.Visible = 2.5, true, C.dim, 4, true
    table.insert(objs, dot)
    local status = label("Ready to load", origin + v2(26, 36), 11, C.dim)

    local btnPos = origin + v2(14, 62)
    local btnSize = v2(size.X - 28, 24)
    rect(btnPos - v2(1, 1), btnSize + v2(2, 2), C.line, 3)
    local fill = rect(btnPos, btnSize, C.btn, 4)
    local btnText = label("Load Pulsar.One", btnPos, 12)
    btnText.Center = true
    btnText.Position = btnPos + v2(btnSize.X / 2, (btnSize.Y - btnText.TextBounds.Y) / 2)

    local function within(p, pos, sz)
        local o = p - pos
        return o.X >= 0 and o.Y >= 0 and o.X < sz.X and o.Y < sz.Y
    end

    local queued, was, pressedOn, dragFrom = false, false, false, nil
    while true do
        local pressed = uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        local m = uis:GetMouseLocation()
        local hover = (not queued) and within(m, btnPos, btnSize)

        if pressed and not was then
            pressedOn = hover
            dragFrom = (not hover and within(m, origin, size)) and m or nil
        elseif not pressed and was and pressedOn and hover then
            queued = true
            pcall(queueScript)
            fill.Color = C.accent
            btnText.Text = "Queued - join a server"
            dot.Color = Color3.fromRGB(80, 220, 130)
            status.Text = "Queued"
            status.Color = C.text
        end

        if pressed and dragFrom then
            local d = m - dragFrom
            dragFrom = m
            origin = origin + d
            btnPos = btnPos + d
            for _, o in objs do o.Position = o.Position + d end
            for _, l in lines do l.From = l.From + d; l.To = l.To + d end
        end

        if not queued then
            fill.Color = (pressed and pressedOn and hover) and C.press or (hover and C.hover or C.btn)
        end

        was = pressed
        task.wait(0.03)
    end
end)

if not ok then pcall(queueScript) end
