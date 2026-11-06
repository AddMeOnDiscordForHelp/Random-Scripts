--[[
    Pulsar.One - lobby card (same flow as amongus-hook fallensurvival/main.lua)

    Upload alongside: Pulsar.One.preload.lua + Pulsar.One.obfuscated.lua
    Set REPO below to your raw github path, then execute this file from the lobby.
]]

local REPO = "https://raw.githubusercontent.com/AddMeOnDiscordForHelp/Random-Scripts/main/"
local PRELOAD_NAME = "Pulsar.One.preload.lua"

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local request = request or http_request
local messagebox = messageboxasync or messagebox
local queueOnTeleport = queue_on_teleport or queueonteleport or queueteleport

local function fail(reason)
    if type(messagebox) == "function" then
        pcall(messagebox, reason, "Pulsar.One", 48)
    end
end

local function safeRequest(url)
    if type(request) ~= "function" then return nil end
    local ok, response = pcall(request, { Url = url, Method = "GET" })
    if not ok or type(response) ~= "table" then return nil end
    if type(response.Body) ~= "string" or response.StatusCode ~= 200 then return nil end
    return response.Body
end

-- Lobby check (same marker amongus-hook uses)
local isInLobby = pcall(function()
    return game:GetService("StarterGui").MainMenu.Main.ServerList
end)

if not isInLobby then
    fail("Please inject from the lobby.\n\nInjecting while in-game is not supported.")
    return
end

if type(queueOnTeleport) ~= "function" then
    fail("Your executor does not support queue_on_teleport.\n\nPlease use a supported executor.")
    return
end

local queueScript = function()
    local preloadSource = safeRequest(REPO .. PRELOAD_NAME)
    if not preloadSource then
        fail("Failed to fetch " .. PRELOAD_NAME)
        return
    end
    local loadFunction, err = loadstring(preloadSource)
    if type(loadFunction) ~= "function" then
        fail("Failed to load " .. PRELOAD_NAME .. "\nSyntax Error: " .. tostring(err))
        return
    end
    queueOnTeleport(string.format("loadstring(%q)();", preloadSource))
end

-- Lobby card (Drawing API)
local ok, err = pcall(function()
    local uis = game:GetService("UserInputService")
    local new = Drawing.new
    local v2 = Vector2.new

    local C = {
        border = Color3.fromRGB(20, 30, 55),
        card = Color3.fromRGB(14, 18, 28),
        text = Color3.fromRGB(235, 240, 255),
        muted = Color3.fromRGB(120, 135, 160),
        accent = Color3.fromRGB(56, 124, 255),
        button = Color3.fromRGB(24, 32, 48),
        hover = Color3.fromRGB(32, 44, 66),
        press = Color3.fromRGB(18, 24, 36),
    }

    local size = v2(260, 106)
    local vp = workspace.CurrentCamera.ViewportSize
    local origin = v2(math.floor(vp.X * 0.72), math.floor(vp.Y * 0.40))

    local objs, lines = {}, {}
    local function rect(pos, sz, radius, color, z)
        local d = new("Square")
        d.Position, d.Size, d.Color, d.ZIndex = pos, sz, color, z
        d.Filled = true
        d.Visible = true
        table.insert(objs, d)
        return d
    end
    local function label(text, pos, sz)
        local d = new("Text")
        d.Text, d.Position, d.Size, d.Color = text, pos, sz, C.text
        d.Visible = true
        d.ZIndex = 6
        table.insert(objs, d)
        return d
    end

    rect(origin - v2(1, 1), size + v2(2, 2), 11, C.border, 1)
    rect(origin, size, 10, C.card, 2)

    local brand = label("Pulsar", origin + v2(16, 14), 17)
    local dot = label(".One", brand.Position + v2(brand.TextBounds.X, 0), 17)
    dot.Color = C.accent

    local statusDot = new("Circle")
    statusDot.Position = origin + v2(19, 48)
    statusDot.Radius, statusDot.Filled = 2.5, true
    statusDot.Color, statusDot.ZIndex = C.muted, 4
    statusDot.Visible = true
    table.insert(objs, statusDot)

    local status = label("Ready to load", origin + v2(27, 40), 12)
    status.Color = C.muted

    local btnPos = origin + v2(16, 66)
    local btnSize = v2(size.X - 32, 24)
    rect(btnPos - v2(1, 1), btnSize + v2(2, 2), 6, C.border, 3)
    local btnFill = rect(btnPos, btnSize, 5, C.button, 4)

    local btnText = label("Load Pulsar.One", btnPos + v2(0, 4), 13)
    btnText.Center = true
    btnText.Position = btnPos + v2(btnSize.X / 2, (btnSize.Y - btnText.TextBounds.Y) / 2)

    local function within(point, pos, sz)
        local o = point - pos
        return o.X >= 0 and o.Y >= 0 and o.X < sz.X and o.Y < sz.Y
    end

    local function moveBy(delta)
        origin = origin + delta
        btnPos = btnPos + delta
        for _, d in objs do d.Position = d.Position + delta end
        for _, l in lines do l.From = l.From + delta; l.To = l.To + delta end
    end

    local queued, wasPressed, pressedOnButton, dragFrom = false, false, false, nil

    while true do
        local pressed = uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        local mouse = uis:GetMouseLocation()
        local hovering = (not queued) and within(mouse, btnPos, btnSize)

        if pressed and not wasPressed then
            pressedOnButton = hovering
            dragFrom = (not hovering and within(mouse, origin, size)) and mouse or nil
        elseif not pressed and wasPressed and pressedOnButton and hovering then
            queued = true
            pcall(queueScript)
            btnFill.Color = C.accent
            btnText.Text = "Queued - join a server"
            statusDot.Color = Color3.fromRGB(80, 220, 130)
            status.Text = "Queued"
            status.Color = C.text
        end

        if pressed and dragFrom then
            moveBy(mouse - dragFrom)
            dragFrom = mouse
        end

        if not queued then
            btnFill.Color = (pressed and pressedOnButton and hovering) and C.press
                or (hovering and C.hover or C.button)
        end

        wasPressed = pressed
        task.wait(0.03)
    end
end)

if not ok then
    -- No Drawing available: just queue immediately
    pcall(queueScript)
end
