--[[
    Pulsar.One loader  (amghook-style: request -> loadstring -> main)
    Set GITHUB_REPO + MAIN_FILE after you upload the build.
    Fallback: if request fails, loads the local file via readfile.
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local GITHUB_REPO = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/"
local MAIN_FILE   = "Pulsar.One.obfuscated.lua"
local LOCAL_FILE  = "Pulsar.One.obfuscated.lua"

local SUPPORTED = {
    placeIDs = { 13800717766, 15479377118, 16849012343, 10228136016 },
    executors = { "Wave", "Swift", "Volt", "Seliware", "Potassium", "Synapse Z" },
    gameName = "Fallen Survival",
    status = "Undetected",
    customMessages = {},
}

local selfKicked = false
local function kickPlayer(reason)
    if selfKicked then return end
    selfKicked = true
    pcall(function() LocalPlayer:Kick("[Pulsar.One] " .. tostring(reason)) end)
end

local executor = "Unknown"
pcall(function()
    if identifyexecutor then executor = identifyexecutor() end
end)

local messagebox = messageboxasync or messagebox
local request = request or http_request
local loadstring = loadstring

local function protectedMessagebox(body, title, id)
    if type(messagebox) ~= "function" then return nil end
    local ok, out = pcall(messagebox, body, title, id)
    if ok then return out end
    ok, out = pcall(messagebox, body, title, 1)
    if ok then return out end
    return nil
end

local function runSource(src, name)
    local loader = loadstring(src, name or "=Pulsar.One")
    if not loader then return false end
    local ok = pcall(loader)
    return ok
end

local function protectedLoad(url)
    if type(request) ~= "function" then return false end
    local ok, response = pcall(request, { Url = url, Method = "GET" })
    if not ok then return false end
    if type(response) ~= "table" then return false end
    if type(response.Body) ~= "string" or response.Body == "" then return false end
    if response.StatusCode and response.StatusCode ~= 200 then return false end
    return runSource(response.Body, "=" .. MAIN_FILE)
end

local function loadLocal()
    if not readfile then return false end
    if isfile and not isfile(LOCAL_FILE) then return false end
    local ok, data = pcall(readfile, LOCAL_FILE)
    if not ok or type(data) ~= "string" then return false end
    return runSource(data, "=" .. LOCAL_FILE)
end

-- Place check (same idea as amghook's supportedGames)
local placeId = game.PlaceId
local gameId = game.GameId
local supported = false
for _, id in ipairs(SUPPORTED.placeIDs) do
    if id == placeId or id == gameId then
        supported = true
        break
    end
end

if not supported then
    local answer = protectedMessagebox(
        "This Game is Unsupported!\n\nPlaceId: " .. tostring(placeId) .. "\n\nLoad anyway?",
        "Pulsar.One [" .. tostring(placeId) .. "]",
        52
    )
    if answer ~= 6 then
        return
    end
end

-- Status / executor warnings (amghook style)
if SUPPORTED.status ~= "Undetected" then
    local answer = protectedMessagebox(
        SUPPORTED.gameName .. " is Currently Marked as " .. SUPPORTED.status .. "!\n\nAre You Sure You Want to Continue?",
        "Pulsar.One",
        52
    )
    if answer ~= 6 then
        return
    end
end

local listed = false
for _, name in ipairs(SUPPORTED.executors) do
    if name == executor then
        listed = true
        break
    end
end

if not listed then
    local answer = protectedMessagebox(
        "Unsupported Executor!\n\n" .. tostring(executor) .. " is not Officially Supported for " ..
        SUPPORTED.gameName .. "\nand may have Undefined Behaviour.\n\nAre You Sure You Want to Continue?",
        "Pulsar.One [" .. tostring(executor) .. "]",
        52
    )
    if answer ~= 6 then
        return
    end
end

-- Load: remote first, local fallback (no prints)
if not protectedLoad(GITHUB_REPO .. MAIN_FILE) then
    if not loadLocal() then
        protectedMessagebox(
            "Pulsar.One failed to load.\n\n" ..
            "executor: " .. tostring(executor) .. "\n" ..
            "url: " .. GITHUB_REPO .. MAIN_FILE .. "\n" ..
            "fallback: " .. LOCAL_FILE,
            "Pulsar.One [" .. tostring(executor) .. "]",
            48
        )
    end
end
