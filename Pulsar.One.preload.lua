--[[
    Pulsar.One - preload stage (no game-script pausing)

    Fetches and runs main.lua after the teleport.
]]

local REPO = "https://raw.githubusercontent.com/AddMeOnDiscordForHelp/Random-Scripts/main/"
local MAIN_NAME = "Pulsar.One.lua"
local GAME_IDS = { 13800717766, 15479377118, 16849012343 }
local LOBBY_IDS = { 10228136016 }

local request = request or http_request
local messagebox = messageboxasync or messagebox
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local selfKicked = false
local function kick(code, description)
    if selfKicked then return end
    selfKicked = true
    local text = "Pulsar.One error (" .. tostring(code) .. ")\n" .. tostring(description)
    pcall(function() LocalPlayer:Kick(text) end)
    if type(messagebox) == "function" then
        pcall(messagebox, text, "Pulsar.One", 48)
    end
end

local function safeRequest(url)
    if type(request) ~= "function" then return nil end
    local ok, response = pcall(request, { Url = url, Method = "GET" })
    if not ok then return nil end
    if type(response) ~= "table" or type(response.Body) ~= "string" or response.StatusCode ~= 200 then
        return nil
    end
    return response.Body
end

-- Place gate
local placeId = game.PlaceId
local gameId = game.GameId
local allowed = false
for _, id in ipairs(GAME_IDS) do
    if id == placeId or id == gameId then allowed = true break end
end
if not allowed then
    for _, id in ipairs(LOBBY_IDS) do
        if id == placeId then allowed = true break end
    end
end
if not allowed then
    return
end

-- Wait until the world is actually present (no script pausing)
task.spawn(function()
    local deadline = os.clock() + 30
    while os.clock() < deadline do
        if workspace:FindFirstChild("Bases") or workspace:FindFirstChild("VFX") then
            break
        end
        task.wait(0.5)
    end

    local source = safeRequest(REPO .. MAIN_NAME)
    if not source then
        kick(1, "request failed for " .. REPO .. MAIN_NAME)
        return
    end

    local loadFunction, err = loadstring(source)
    if type(loadFunction) ~= "function" then
        kick(2, "syntax error in " .. MAIN_NAME .. ": " .. tostring(err))
        return
    end

    local ok, runErr = pcall(loadFunction)
    if not ok then
        kick(3, "runtime error: " .. tostring(runErr))
    end
end)
