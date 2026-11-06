--[[
    Pulsar.One - FRAMEBREAK targeted combat dump
    Writes to: FrameBreakDump/
      - decompiled/*.lua or bytecode/*.luac for the combat modules
      - report.txt
      - combat_calls.txt  (first FireServer calls on Net.CombatCmd)
      - raycast_calls.txt (first workspace:Raycast calls while firing)

    Run in-game, fire 3-5 shots at a player, wait ~5 seconds.
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Controllers = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Controllers")

local decompilerName, decompilerFn = nil, nil
for _, name in ipairs({
    "decompile", "psms", "decompile_luau", "luauDecompile", "decompileBytecode",
    "decompilebytecode", "decompiler", "luau_decompile", "getdecompiledscript",
    "decompilescript", "getscriptsource",
}) do
    local ok, fn = pcall(function() return _G[name] end)
    if ok and type(fn) == "function" then
        decompilerName, decompilerFn = name, fn
        break
    end
end
if not decompilerName then
    pcall(function()
        local p = _G.Potassium or _G.potassium
        if type(p) == "table" then
            for _, key in ipairs({ "decompile", "psms", "decompilebytecode", "decompileLuau" }) do
                if type(p[key]) == "function" then
                    decompilerName, decompilerFn = "Potassium." .. key, p[key]
                    return
                end
            end
        end
    end)
end

local function ensureDir(path)
    if not makefolder then return end
    local cur = ""
    for part in string.gmatch(path, "[^/]+") do
        cur = cur == "" and part or (cur .. "/" .. part)
        if not (isfolder and isfolder(cur)) then pcall(makefolder, cur) end
    end
end

local function write(path, text)
    if writefile then pcall(writefile, path, text) end
end

ensureDir("FrameBreakDump/decompiled")
ensureDir("FrameBreakDump/bytecode")

local targets = {
    { "WeaponController", Controllers:FindFirstChild("WeaponController") },
    { "Aim", Controllers:FindFirstChild("Aim") },
    { "InputController", Controllers:FindFirstChild("InputController") },
    { "ClientState", Controllers:FindFirstChild("ClientState") },
    { "AimTraceSender", Controllers:FindFirstChild("AimTraceSender") },
    { "ClientGuard", Controllers:FindFirstChild("ClientGuard") },
    { "AimAssist", Controllers:FindFirstChild("AimAssist") },
    { "Net", RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Net") },
    { "WeaponDefinitions", RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("WeaponDefinitions") },
    { "GameConfig", RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("GameConfig") },
}

local report = {
    "decompiler=" .. tostring(decompilerName or "none"),
    "getscriptbytecode=" .. tostring(getscriptbytecode ~= nil),
    "hookfunction=" .. tostring(hookfunction ~= nil),
    "getrawmetatable=" .. tostring(getrawmetatable ~= nil),
}

if getscriptbytecode then
    for _, entry in ipairs(targets) do
        local name, obj = entry[1], entry[2]
        if obj then
            local ok, code = pcall(getscriptbytecode, obj)
            if ok and type(code) == "string" and #code > 0 then
                write("FrameBreakDump/bytecode/" .. name .. ".luac", code)
                local decompiled = false
                if decompilerFn then
                    local ok2, src = pcall(decompilerFn, code)
                    if ok2 and type(src) == "string" and #src > 0 then
                        write("FrameBreakDump/decompiled/" .. name .. ".lua", src)
                        decompiled = true
                    end
                end
                report[#report + 1] = name .. "=bytes:" .. #code .. ",decompiled:" .. tostring(decompiled)
            else
                report[#report + 1] = name .. "=bytecode_failed:" .. tostring(code)
            end
        else
            report[#report + 1] = name .. "=missing"
        end
    end
else
    report[#report + 1] = "no_getscriptbytecode"
end

-- resolve the game's own Net module + CombatCmd remote
local cmd = nil
local netModule = RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Net")
if netModule then
    local ok, net = pcall(require, netModule)
    if ok and type(net) == "table" and type(net.get) == "function" then
        local ok2, remote = pcall(net.get, "CombatCmd")
        if ok2 and remote and remote:IsA("RemoteEvent") then
            cmd = remote
            report[#report + 1] = "CombatCmd=" .. remote.ClassName
        else
            report[#report + 1] = "CombatCmd=not_found_via_net"
        end
    else
        report[#report + 1] = "Net=require_failed"
    end
else
    report[#report + 1] = "Net=missing"
end

write("FrameBreakDump/report.txt", table.concat(report, "\n"))

local function repr(v, depth)
    depth = depth or 0
    if depth > 2 then return "..." end
    local t = typeof(v)
    if t == "Instance" then
        local ok, name = pcall(function() return v:GetFullName() end)
        return ok and name or v.ClassName
    elseif t == "Vector3" then
        return string.format("Vector3(%.2f,%.2f,%.2f)", v.X, v.Y, v.Z)
    elseif t == "CFrame" then
        return "CFrame"
    elseif type(v) == "table" then
        local parts = {}
        for k, val in pairs(v) do
            if #parts >= 12 then
                parts[#parts + 1] = "..."
                break
            end
            parts[#parts + 1] = tostring(k) .. "=" .. repr(val, depth + 1)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else
        return tostring(v)
    end
end

local combatLog = {}
local rayLog = {}

if getrawmetatable and newcclosure and setreadonly and getnamecallmethod then
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    if oldNamecall then
        pcall(function()
            setreadonly(mt, false)
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()

                if method == "Raycast" and self == workspace and #rayLog < 25 then
                    local origin, direction, params = ...
                    if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                        local caller
                        if getcallingscript then pcall(function() caller = getcallingscript() end) end
                        rayLog[#rayLog + 1] = string.format(
                            "caller=%s origin=%s dir=%s params=%s",
                            caller and caller.Name or "?",
                            repr(origin), repr(direction), repr(params)
                        )
                    end
                elseif method == "FireServer" and cmd and self == cmd and #combatLog < 12 then
                    local args = { ... }
                    combatLog[#combatLog + 1] = repr(args)
                end

                return oldNamecall(self, ...)
            end)
            setreadonly(mt, true)
        end)
    end

    task.spawn(function()
        for _ = 1, 30 do
            task.wait(1)
            write("FrameBreakDump/combat_calls.txt", table.concat(combatLog, "\n"))
            write("FrameBreakDump/raycast_calls.txt", table.concat(rayLog, "\n"))
        end
        pcall(function()
            setreadonly(mt, false)
            rawset(mt, "__namecall", oldNamecall)
            setreadonly(mt, true)
        end)
        write("FrameBreakDump/combat_calls.txt", table.concat(combatLog, "\n"))
        write("FrameBreakDump/raycast_calls.txt", table.concat(rayLog, "\n"))
    end)
else
    write("FrameBreakDump/combat_calls.txt", "no namecall hook support")
    write("FrameBreakDump/raycast_calls.txt", "no namecall hook support")
end

if messageboxasync or messagebox then
    pcall(messageboxasync or messagebox,
        "FRAMEBREAK dump written to FrameBreakDump/\n\nFire 3-5 shots at a player now.\nLogs update for 30s.",
        "Pulsar.One", 48)
end
