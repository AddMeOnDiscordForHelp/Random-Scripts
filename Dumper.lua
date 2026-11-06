--[[
    Fust Survival - full client dumper
    Writes to the executor workspace folder:
      FustDump/
        meta.txt
        services.txt
        <Service>.txt        (full tree per service)
        remotes.txt
        interesting.txt
        scripts/_index.txt
        scripts/<n>_<name>.lua
    No console prints. Silent unless SHOW_SUMMARY is true.
]]

local SHOW_SUMMARY = true
local MAX_NODES = 250000
local MAX_SCRIPTS = 400
local MAX_SOURCE = 200 * 1024

local SKIP_SERVICES = {
    CoreGui = true,
    CorePackages = true,
    ScriptContext = true,
    RobloxPluginGuiService = true,
    PluginGuiService = true,
    TestService = true,
}

local KEYWORDS = {
    "inventory", "viewmodel", "tool", "gun", "weapon", "hit", "damage", "fire",
    "shoot", "ammo", "recoil", "spread", "armor", "armour", "melee", "swing",
    "loot", "crate", "node", "tree", "rock", "ore", "zombie", "npc", "military",
    "score", "quest", "shop", "trade", "bank", "storage", "vehicle", "car",
}

local Players = game:GetService("Players")

local function has(name)
    local ok, v = pcall(function() return _G[name] end)
    return ok and type(v) == "function"
end

local writefile = writefile
local appendfile = appendfile
local makefolder = makefolder
local isfolder = isfolder
local isfile = isfile
local listfiles = listfiles
local delfile = delfile

local function splitPath(path)
    local out = {}
    for part in string.gmatch(path, "[^/]+") do out[#out + 1] = part end
    return out
end

local function ensureDir(path)
    if not makefolder then return false end
    local parts = splitPath(path)
    local cur = ""
    for _, part in ipairs(parts) do
        cur = (cur == "") and part or (cur .. "/" .. part)
        if not (isfolder and isfolder(cur)) then
            pcall(makefolder, cur)
        end
    end
    return true
end

local function write(path, text)
    if not writefile then return false end
    local ok = pcall(writefile, path, text)
    return ok
end

local function sanitize(name)
    name = tostring(name or "unnamed")
    name = name:gsub("[^%w%-%_%. ]", "_")
    name = name:gsub("%s+", "_")
    if #name > 80 then name = name:sub(1, 80) end
    return name
end

local function pathOf(inst)
    local ok, full = pcall(function() return inst:GetFullName() end)
    return ok and full or tostring(inst)
end

local function attrsOf(inst)
    local out = {}
    local ok, attrs = pcall(function() return inst:GetAttributes() end)
    if ok and type(attrs) == "table" then
        for k, v in pairs(attrs) do
            local val
            if type(v) == "string" then val = '"' .. v .. '"'
            elseif type(v) == "boolean" or type(v) == "number" then val = tostring(v)
            else val = tostring(v) end
            out[#out + 1] = k .. "=" .. val
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
    "localCharacter=" .. tostring((function()
        local ok, lp = pcall(function() return game:GetService("Players").LocalPlayer end)
        return ok and lp and lp.Character ~= nil
    end)()),
    "time=" .. tostring(os.date("%Y-%m-%d %H:%M:%S")),
}
ensureDir("FustDump")
write("FustDump/meta.txt", table.concat(meta, "\n"))

local serviceLines = {}
local serviceFiles = {}
local totalNodes = 0

local function dumpRoot(rootName, root)
    local lines = {}
    local stack = { { inst = root, depth = 0 } }
    local count = 0
    local prefix = pathOf(root)

    while #stack > 0 and count < MAX_NODES do
        local item = table.remove(stack)
        local inst = item.inst
        if inst then
            count = count + 1
            if count % 4000 == 0 then task.wait() end
            local line = pathOf(inst) .. " :: " .. inst.ClassName .. attrsOf(inst) .. tagsOf(inst)
            lines[#lines + 1] = line
            local ok, kids = pcall(function() return inst:GetChildren() end)
            if ok and kids then
                for i = #kids, 1, -1 do
                    stack[#stack + 1] = { inst = kids[i], depth = item.depth + 1 }
                end
            end
        end
    end

    totalNodes = totalNodes + count
    write("FustDump/" .. sanitize(rootName) .. ".txt", table.concat(lines, "\n"))
    return count
end

-- full service tree
for _, service in ipairs(game:GetChildren()) do
    if not SKIP_SERVICES[service.ClassName] and not SKIP_SERVICES[service.Name] then
        local ok, count = pcall(dumpRoot, service.Name, service)
        if ok then
            serviceLines[#serviceLines + 1] = string.format("%-32s %d", service.Name, count)
            serviceFiles[#serviceFiles + 1] = "FustDump/" .. sanitize(service.Name) .. ".txt"
        end
    end
end
write("FustDump/services.txt", table.concat(serviceLines, "\n"))

-- remotes
local remoteLines = {}
local interesting = {}
local scriptIndex = { "path\tfile" }
local scriptCount = 0
ensureDir("FustDump/scripts")

local seen = {}

local function scan(root)
    local stack = { root }
    local scanned = 0
    while #stack > 0 and scanned < MAX_NODES do
        local inst = table.remove(stack)
        if inst and not seen[inst] then
            seen[inst] = true
            scanned = scanned + 1
            if scanned % 4000 == 0 then task.wait() end
            local cn = inst.ClassName
            local low = inst.Name:lower()

            if cn == "RemoteEvent" or cn == "RemoteFunction" or cn == "UnreliableRemoteEvent" or cn == "BindableEvent" or cn == "BindableFunction" then
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
                if src then
                    scriptCount = scriptCount + 1
                    local file = string.format("FustDump/scripts/%03d_%s.lua", scriptCount, sanitize(inst.Name))
                    write(file, src)
                    scriptIndex[#scriptIndex + 1] = pathOf(inst) .. "\t" .. file
                end
            end

            local ok, kids = pcall(function() return inst:GetChildren() end)
            if ok and kids then
                for i = #kids, 1, -1 do
                    if not SKIP_SERVICES[kids[i].Name] then
                        stack[#stack + 1] = kids[i]
                    end
                end
            end
        end
    end
end

for _, child in ipairs(game:GetChildren()) do
    if not SKIP_SERVICES[child.Name] and not SKIP_SERVICES[child.ClassName] then
        pcall(scan, child)
    end
end

write("FustDump/remotes.txt", table.concat(remoteLines, "\n"))
write("FustDump/interesting.txt", table.concat(interesting, "\n"))
write("FustDump/scripts/_index.txt", table.concat(scriptIndex, "\n"))

-- GUI / lobby markers
do
    local lines = {}
    local function dumpGui(root, label, maxDepth)
        if not root then return end
        local stack = { { inst = root, depth = 0 } }
        while #stack > 0 do
            local item = table.remove(stack)
            local inst = item.inst
            if inst then
                local line = pathOf(inst) .. " :: " .. inst.ClassName
                if inst:IsA("GuiObject") then
                    local props = {}
                    local okv, vis = pcall(function() return inst.Visible end)
                    if okv then props[#props + 1] = "visible=" .. tostring(vis) end
                    local oke, en = pcall(function() return inst.Enabled end)
                    if oke then props[#props + 1] = "enabled=" .. tostring(en) end
                    local oks, sz = pcall(function() return inst.AbsoluteSize end)
                    if oks then props[#props + 1] = "size=" .. tostring(sz) end
                    line = line .. " " .. table.concat(props, " ")
                end
                lines[#lines + 1] = line
                if item.depth < maxDepth then
                    local ok, kids = pcall(function() return inst:GetChildren() end)
                    if ok and kids then
                        for i = #kids, 1, -1 do
                            stack[#stack + 1] = { inst = kids[i], depth = item.depth + 1 }
                        end
                    end
                end
            end
        end
    end
    local ok, lp = pcall(function() return game:GetService("Players").LocalPlayer end)
    if ok and lp then
        dumpGui(lp:FindFirstChild("PlayerGui"), "PlayerGui", 4)
    end
    dumpGui(game:GetService("StarterGui"), "StarterGui", 4)
    local cam = workspace.CurrentCamera
    if cam then
        lines[#lines + 1] = "Camera :: " .. tostring(cam.CameraType) .. " fov=" .. tostring(cam.FieldOfView) .. " vp=" .. tostring(cam.ViewportSize)
    end
    write("FustDump/gui.txt", table.concat(lines, "\n"))
end

if SHOW_SUMMARY and (messageboxasync or messagebox) then
    local box = messageboxasync or messagebox
    local summary = string.format(
        "Dump complete\n\nservices: %d\nnodes: %d\nremotes: %d\ninteresting: %d\nscripts: %d\n\nFustDump/",
        #serviceLines, totalNodes, #remoteLines, #interesting, scriptCount
    )
    pcall(box, summary, "Fust Dumper", 48)
end

return {
    services = #serviceLines,
    nodes = totalNodes,
    remotes = #remoteLines,
    interesting = #interesting,
    scripts = scriptCount,
}
