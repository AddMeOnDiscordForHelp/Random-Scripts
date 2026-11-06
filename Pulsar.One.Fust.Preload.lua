-- Pulsar.One - Fust preload stage (runs after teleport)
local REPO = "https://raw.githubusercontent.com/AddMeOnDiscordForHelp/Random-Scripts/main/"
local MAIN = "Pulsar.One.Fust.lua"

local request = request or http_request
local messagebox = messageboxasync or messagebox
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local function notify(text)
    if type(messagebox) == "function" then pcall(messagebox, text, "Pulsar.One", 48) end
end

local function fetch(url)
    if type(request) ~= "function" then return nil end
    local ok, res = pcall(request, { Url = url, Method = "GET" })
    if not ok or type(res) ~= "table" then return nil end
    if type(res.Body) ~= "string" or res.StatusCode ~= 200 then return nil end
    return res.Body
end

task.spawn(function()
    local deadline = os.clock() + 30
    while os.clock() < deadline do
        if workspace:FindFirstChild("Npcs") or workspace:FindFirstChild("Nodes") then break end
        task.wait(0.5)
    end

    local src = fetch(REPO .. MAIN .. "?v=" .. tostring(os.time()))
    if not src then notify("Failed to fetch " .. MAIN) return end
    getgenv().pulsarFustFromLobby = true
    local fn, err = loadstring(src)
    if type(fn) ~= "function" then notify("Syntax error: " .. tostring(err)) return end
    local ok, runErr = pcall(fn)
    if not ok then
        notify("Load error: " .. tostring(runErr))
    elseif getgenv and getgenv().pulsarFustError then
        notify("Main error: " .. tostring(getgenv().pulsarFustError))
    elseif getgenv and not getgenv().pulsarFustUI then
        notify("Ran, but no UI was built.\n\nNo error captured.")
    elseif getgenv and getgenv().pulsarDrawingDir then
        local dir = getgenv().pulsarDrawingDir
        if not dir.Parent then
            notify("UI exists but has no parent.")
        elseif not dir.Enabled then
            notify("UI exists but is disabled.")
        end
    end
end)
