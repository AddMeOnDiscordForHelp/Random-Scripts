--[[
    FULL GAME DUMPER (client)
    Output (executor workspace):
      FustDump/
        meta.txt
        services.txt
        tree/<Service>.txt
        props/<Service>.txt
        remotes.txt
        tools.txt
        assets.txt
        gui.txt
        modules.txt
        interesting.txt
        scripts/_index.txt
        scripts/*.lua
    Silent. Optional summary messagebox.
]]

local SHOW_SUMMARY = true
local MAX_NODES = 250000
local MAX_SCRIPTS = 500
local MAX_SOURCE = 300 * 1024
local DUMP_BYTECODE = true
local MAX_MODULE_TEXT = 60000

local SKIP = {
    CoreGui = true, CorePackages = true, ScriptContext = true,
    RobloxPluginGuiService = true, PluginGuiService = true, TestService = true,
}

local KEYWORDS = {
    "inventory", "viewmodel", "tool", "gun", "weapon", "hit", "damage", "fire",
    "shoot", "ammo", "recoil", "spread", "armor", "armour", "melee", "swing",
    "loot", "crate", "chest", "node", "tree", "rock", "ore", "zombie", "npc",
    "military", "score", "quest", "shop", "trade", "bank", "storage", "vehicle",
    "car", "heli", "boat", "atv", "predict", "ballistic", "gravity",
}

local Players = game:GetService("Players")
local writefile, appendfile, makefolder = writefile, appendfile, makefolder
local isfolder, isfile, listfiles, delfile = isfolder, isfile, listfiles, delfile

local function splitPath(path)
    local out = {}
    for part in string.gmatch(path, "[^/]+") do out[#out + 1] = part end
    return out
end

local function ensureDir(path)
    if not makefolder then return end
    local cur = ""
    for _, part in ipairs(splitPath(path)) do
        cur = (cur == "") and part or (cur .. "/" .. part)
        if not (isfolder and isfolder(cur)) then pcall(makefolder, cur) end
    end
end

local function write(path, text)
    if not writefile then return false end
    return pcall(writefile, path, text)
end

local function sanitize(name)
    name = tostring(name or "unnamed"):gsub("[^%w%-%_%. ]", "_"):gsub("%s+", "_")
    if #name > 90 then name = name:sub(1, 90) end
    return name
end

local function pathOf(inst)
    local ok, full = pcall(function() return inst:GetFullName() end)
    return ok and full or tostring(inst)
end

local function safeGet(inst, prop)
    local ok, v = pcall(function() return inst[prop] end)
    if ok then return v end
    return nil
end

local function valStr(v)
    local t = typeof(v)
    if t == "string" then return '"' .. v:gsub('"', "'") .. '"' end
    if t == "boolean" or t == "number" then return tostring(v) end
    if t == "Vector3" then return string.format("(%.2f,%.2f,%.2f)", v.X, v.Y, v.Z) end
    if t == "CFrame" then
        local p = v.Position
        return string.format("CF(%.1f,%.1f,%.1f)", p.X, p.Y, p.Z)
    end
    if t == "Color3" then return string.format("RGB(%d,%d,%d)", v.R * 255, v.G * 255, v.B * 255) end
    if t == "UDim2" then return string.format("UDim2(%d,%d,%d,%d)", v.X.Scale * 100, v.X.Offset, v.Y.Scale * 100, v.Y.Offset) end
    if t == "EnumItem" then return tostring(v) end
    return tostring(v)
end

local assets = {}

local function noteAsset(v)
    if type(v) ~= "string" then return end
    for id in string.gmatch(v, "rbxassetid://(%d+)") do assets[id] = true end
    for id in string.gmatch(v, "rbxasset://(%S+)") do assets["rbxasset:" .. id] = true end
end

local function attrsOf(inst)
    local out = {}
    local ok, attrs = pcall(function() return inst:GetAttributes() end)
    if ok and type(attrs) == "table" then
        for k, v in pairs(attrs) do
            out[#out + 1] = k .. "=" .. valStr(v)
        end
        table.sort(out)
    end
    return #out > 0 and (" {" .. table.concat(out, ", ") .. "}") or ""
end

local function tagsOf(inst)
    if not inst.GetTags then return "" end
    local ok, tags = pcall(function() return inst:GetTags() end)
    if ok and type(tags) == "table" and #tags > 0 then
        return " [" .. table.concat(tags, ",") .. "]"
    end
    return ""
end

local function propsOf(inst)
    local cn = inst.ClassName
    local out = {}
    local function add(name)
        local v = safeGet(inst, name)
        if v ~= nil then
            out[#out + 1] = name .. "=" .. valStr(v)
            noteAsset(v)
        end
    end

    if inst:IsA("BasePart") then
        for _, p in ipairs({ "Size", "Position", "CFrame", "Color", "Material", "Transparency", "Anchored", "CanCollide", "CanTouch", "Shape", "MeshId", "TextureID" }) do add(p) end
    elseif inst:IsA("Model") then
        local pp = safeGet(inst, "PrimaryPart")
        if pp then out[#out + 1] = "PrimaryPart=" .. pathOf(pp) end
    elseif inst:IsA("ValueBase") then
        add("Value")
    elseif cn == "Sound" then
        for _, p in ipairs({ "SoundId", "Volume", "Looped", "PlaybackSpeed", "RollOffMode" }) do add(p) end
    elseif cn == "Animation" then
        add("AnimationId")
    elseif cn == "Decal" or cn == "Texture" then
        add("Texture")
    elseif inst:IsA("GuiObject") then
        for _, p in ipairs({ "Visible", "Enabled", "Text", "Image", "ImageColor3", "TextColor3", "TextSize", "AbsoluteSize", "Position" }) do add(p) end
        if cn == "ScreenGui" then add("DisplayOrder") end
    elseif cn == "Tool" then
        for _, p in ipairs({ "ToolTip", "CanBeDropped", "RequiresHandle", "Enabled" }) do add(p) end
    elseif cn == "ParticleEmitter" then
        for _, p in ipairs({ "Texture", "Rate", "Lifetime", "Speed", "Enabled" }) do add(p) end
    elseif cn == "ProximityPrompt" then
        for _, p in ipairs({ "ActionText", "ObjectText", "Enabled", "MaxActivationDistance" }) do add(p) end
    elseif cn == "Attachment" then
        add("WorldPosition")
    elseif cn == "Light" or cn:find("Light$") then
        for _, p in ipairs({ "Brightness", "Color", "Range", "Enabled" }) do add(p) end
    end

    if #out == 0 then return nil end
    return table.concat(out, " ")
end

local meta = {
    "placeId=" .. tostring(game.PlaceId),
    "gameId=" .. tostring(game.GameId),
    "jobId=" .. tostring(game.JobId),
    "creator=" .. tostring(game.CreatorId),
    "executor=" .. tostring(select(2, pcall(function() return identifyexecutor and identifyexecutor() end))),
    "queue_on_teleport=" .. tostring(queue_on_teleport ~= nil or queueonteleport ~= nil or queueteleport ~= nil),
    "messagebox=" .. tostring((messageboxasync or messagebox) ~= nil),
    "drawing=" .. tostring(_G.Drawing ~= nil),
    "hookfunction=" .. tostring(hookfunction ~= nil),
    "getscriptbytecode=" .. tostring(getscriptbytecode ~= nil),
    "time=" .. tostring(os.date("%Y-%m-%d %H:%M:%S")),
}
ensureDir("FustDump/tree")
ensureDir("FustDump/props")
ensureDir("FustDump/scripts")
ensureDir("FustDump/bytecode")
write("FustDump/meta.txt", table.concat(meta, "\n"))

local serviceLines = {}
local totalNodes = 0

local function dumpService(name, root)
    local tree, props = {}, {}
    local stack = { root }
    local count = 0
    while #stack > 0 and count < MAX_NODES do
        local inst = table.remove(stack)
        if inst then
            count = count + 1
            if count % 3000 == 0 then task.wait() end
            tree[#tree + 1] = pathOf(inst) .. " :: " .. inst.ClassName .. attrsOf(inst) .. tagsOf(inst)
            local p = propsOf(inst)
            if p then props[#props + 1] = pathOf(inst) .. " :: " .. p end
            local ok, kids = pcall(function() return inst:GetChildren() end)
            if ok and kids then
                for i = #kids, 1, -1 do stack[#stack + 1] = kids[i] end
            end
        end
    end
    totalNodes = totalNodes + count
    write("FustDump/tree/" .. sanitize(name) .. ".txt", table.concat(tree, "\n"))
    write("FustDump/props/" .. sanitize(name) .. ".txt", table.concat(props, "\n"))
    return count
end

for _, service in ipairs(game:GetChildren()) do
    if not SKIP[service.ClassName] and not SKIP[service.Name] then
        local ok, count = pcall(dumpService, service.Name, service)
        if ok then
            serviceLines[#serviceLines + 1] = string.format("%-34s %d", service.Name, count)
        end
    end
end
write("FustDump/services.txt", table.concat(serviceLines, "\n"))

-- remotes / scripts / interesting
local remoteLines, interesting, scriptIndex = {}, {}, { "path\tfile" }
local bytecodeIndex = { "path\tfile" }
local scriptCount, seen = 0, {}

local function scan(root)
    local stack = { root }
    local n = 0
    while #stack > 0 and n < MAX_NODES do
        local inst = table.remove(stack)
        if inst and not seen[inst] then
            seen[inst] = true
            n = n + 1
            if n % 3000 == 0 then task.wait() end
            local cn, low = inst.ClassName, inst.Name:lower()

            if cn == "RemoteEvent" or cn == "RemoteFunction" or cn == "UnreliableRemoteEvent"
                or cn == "BindableEvent" or cn == "BindableFunction" then
                remoteLines[#remoteLines + 1] = pathOf(inst) .. " :: " .. cn
            end

            for _, kw in ipairs(KEYWORDS) do
                if low:find(kw, 1, true) then
                    interesting[#interesting + 1] = pathOf(inst) .. " :: " .. cn .. " [kw=" .. kw .. "]" .. attrsOf(inst)
                    break
                end
            end

            if (cn == "LocalScript" or cn == "ModuleScript" or cn == "Script") and scriptCount < MAX_SCRIPTS then
                local src
                local ok, s = pcall(function() return inst.Source end)
                if ok and type(s) == "string" and #s > 0 and #s <= MAX_SOURCE then
                    src = s
                elseif getscriptbytecode then
                    local ok2, code = pcall(getscriptbytecode, inst)
                    if ok2 and type(code) == "string" and #code > 0 then
                        src = "--[bytecode]\n" .. code
                    end
                end
                scriptCount = scriptCount + 1
                if src then
                    local file = string.format("FustDump/scripts/%03d_%s.lua", scriptCount, sanitize(inst.Name))
                    write(file, src)
                    scriptIndex[#scriptIndex + 1] = pathOf(inst) .. "\t" .. file
                end
                if DUMP_BYTECODE and getscriptbytecode then
                    local okb, code = pcall(getscriptbytecode, inst)
                    if okb and type(code) == "string" and #code > 0 then
                        local bfile = string.format("FustDump/bytecode/%03d_%s.luac", scriptCount, sanitize(inst.Name))
                        write(bfile, code)
                        bytecodeIndex[#bytecodeIndex + 1] = pathOf(inst) .. "\t" .. bfile
                    end
                end
            end

            local ok, kids = pcall(function() return inst:GetChildren() end)
            if ok and kids then
                for i = #kids, 1, -1 do
                    if not SKIP[kids[i].Name] then stack[#stack + 1] = kids[i] end
                end
            end
        end
    end
end

for _, child in ipairs(game:GetChildren()) do
    if not SKIP[child.Name] and not SKIP[child.ClassName] then pcall(scan, child) end
end

write("FustDump/remotes.txt", table.concat(remoteLines, "\n"))
write("FustDump/interesting.txt", table.concat(interesting, "\n"))
write("FustDump/scripts/_index.txt", table.concat(scriptIndex, "\n"))
write("FustDump/bytecode/_index.txt", table.concat(bytecodeIndex, "\n"))

-- tools
do
    local lines = {}
    local ok, containers = pcall(function()
        local out = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            local bp = plr:FindFirstChild("Backpack")
            if bp then out[#out + 1] = bp end
            local ch = plr.Character
            if ch then out[#out + 1] = ch end
        end
        out[#out + 1] = workspace
        return out
    end)
    if ok then
        for _, c in ipairs(containers) do
            local ok2, tools = pcall(function() return c:GetDescendants() end)
            if ok2 then
                for _, tool in ipairs(tools) do
                    if tool:IsA("Tool") then
                        local parts = {}
                        for _, d in ipairs(tool:GetDescendants()) do
                            if d:IsA("BasePart") then parts[#parts + 1] = d.Name end
                        end
                        lines[#lines + 1] = pathOf(tool) .. " :: " .. table.concat(parts, ",") .. attrsOf(tool)
                    end
                end
            end
        end
    end
    write("FustDump/tools.txt", table.concat(lines, "\n"))
end

-- modules (client-visible) return-value shapes
do
    local lines = {}
    local root = game:GetService("ReplicatedStorage")
    local stack = { root }
    local n = 0
    while #stack > 0 and n < 400 do
        local inst = table.remove(stack)
        if inst then
            n = n + 1
            local ok, kids = pcall(function() return inst:GetChildren() end)
            if ok and kids then
                for i = #kids, 1, -1 do stack[#stack + 1] = kids[i] end
            end
            if inst:IsA("ModuleScript") then
                local ok2, mod = pcall(require, inst)
                if ok2 then
                    local parts = { pathOf(inst) }
                    local function walk(v, depth)
                        if depth > 2 then return end
                        if type(v) == "table" then
                            local keys = {}
                            for k, val in pairs(v) do
                                if type(k) == "string" or type(k) == "number" then
                                    keys[#keys + 1] = tostring(k)
                                    if type(val) == "table" then
                                        walk(val, depth + 1)
                                    else
                                        parts[#parts + 1] = string.rep("  ", depth) .. tostring(k) .. "=" .. valStr(val)
                                    end
                                end
                                if #table.concat(parts, "\n") > MAX_MODULE_TEXT then return end
                            end
                            if #keys > 0 then
                                parts[#parts + 1] = string.rep("  ", depth) .. "keys: " .. table.concat(keys, ", ")
                            end
                        end
                    end
                    walk(mod, 1)
                    lines[#lines + 1] = table.concat(parts, "\n")
                end
            end
        end
    end
    write("FustDump/modules.txt", table.concat(lines, "\n\n"))
end

-- gui
do
    local lines = {}
    local function dumpGui(root, maxDepth)
        if not root then return end
        local stack = { { inst = root, depth = 0 } }
        while #stack > 0 do
            local item = table.remove(stack)
            local inst = item.inst
            if inst then
                local line = pathOf(inst) .. " :: " .. inst.ClassName
                local props = {}
                local okv, vis = pcall(function() return inst.Visible end)
                if okv then props[#props + 1] = "visible=" .. tostring(vis) end
                local oke, en = pcall(function() return inst.Enabled end)
                if oke then props[#props + 1] = "enabled=" .. tostring(en) end
                local oks, sz = pcall(function() return inst.AbsoluteSize end)
                if oks then props[#props + 1] = "size=" .. tostring(sz) end
                if #props > 0 then line = line .. " " .. table.concat(props, " ") end
                lines[#lines + 1] = line
                if item.depth < maxDepth then
                    local ok, kids = pcall(function() return inst:GetChildren() end)
                    if ok and kids then
                        for i = #kids, 1, -1 do stack[#stack + 1] = { inst = kids[i], depth = item.depth + 1 } end
                    end
                end
            end
        end
    end
    local ok, lp = pcall(function() return Players.LocalPlayer end)
    if ok and lp then dumpGui(lp:FindFirstChild("PlayerGui"), 4) end
    dumpGui(game:GetService("StarterGui"), 4)
    local cam = workspace.CurrentCamera
    if cam then
        lines[#lines + 1] = "Camera :: " .. tostring(cam.CameraType) .. " fov=" .. tostring(cam.FieldOfView) .. " vp=" .. tostring(cam.ViewportSize)
    end
    write("FustDump/gui.txt", table.concat(lines, "\n"))
end

-- anti-cheat exposure report
do
    local lines = {}
    local fust = game:GetService("ReplicatedStorage"):FindFirstChild("Fust")
    local remotes = fust and fust:FindFirstChild("Remotes")

    lines[#lines + 1] = "-- remotes of interest --"
    if remotes then
        for _, rem in ipairs({
            "DeviceReport", "FpsProbe", "MotionSync", "StateCheck", "StateSync",
            "CharSync", "AbuseEvent", "VitalsSync", "LookPitch", "SprintState",
            "CrouchState", "GunState", "BulletHit", "Shoot", "Fire", "Swing",
        }) do
            local r = remotes:FindFirstChild(rem)
            if r then lines[#lines + 1] = "remote " .. rem .. " :: " .. r.ClassName end
        end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "-- Config flags (AC related) --"
    local ok, cfg = pcall(function()
        local mod = fust and fust:FindFirstChild("Config")
        return mod and require(mod)
    end)
    if ok and type(cfg) == "table" then
        local keys = {}
        for k, v in pairs(cfg) do
            if type(k) == "string" and (k:find("SHIELD") or k:find("GUARD") or k:find("AC")
                or k:find("BAN") or k:find("RATE") or k:find("BATCH") or k:find("MOVE")) then
                keys[#keys + 1] = k .. "=" .. tostring(v)
            end
        end
        table.sort(keys)
        for _, l in ipairs(keys) do lines[#lines + 1] = l end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "-- client AC-ish scripts --"
    local lp = game:GetService("Players").LocalPlayer
    local containers = {
        lp and lp:FindFirstChild("PlayerScripts"),
        lp and lp:FindFirstChild("PlayerGui"),
        fust,
        game:GetService("ReplicatedStorage"),
    }
    for _, c in ipairs(containers) do
        if c then
            local ok2, kids = pcall(function() return c:GetDescendants() end)
            if ok2 then
                for _, d in ipairs(kids) do
                    local n = d.Name:lower()
                    if n:find("ac") or n:find("shield") or n:find("guard")
                        or n:find("admin") or n:find("staff") or n:find("ban")
                        or n:find("report") or n:find("probe") then
                        lines[#lines + 1] = pathOf(d) .. " :: " .. d.ClassName
                    end
                end
            end
        end
    end
    write("FustDump/ac_report.txt", table.concat(lines, "\n"))
end

-- assets
do
    local list = {}
    for id in pairs(assets) do list[#list + 1] = id end
    table.sort(list)
    write("FustDump/assets.txt", table.concat(list, "\n"))
end

if SHOW_SUMMARY and (messageboxasync or messagebox) then
    local box = messageboxasync or messagebox
    local summary = string.format(
        "Full dump complete\n\nservices: %d\nnodes: %d\nremotes: %d\ninteresting: %d\nscripts: %d\nassets: %d\n\nFustDump/",
        #serviceLines, totalNodes, #remoteLines, #interesting, scriptCount, (function() local c = 0 for _ in pairs(assets) do c = c + 1 end return c end)()
    )
    pcall(box, summary, "Pulsar.One Dumper", 48)
end
