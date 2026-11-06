--[[
    Pulsar.One - dumper + auto-decompile (Potassium/PSMS aware)
    Tries known decompiler globals; if none exist, saves .luac for PSMS UI.
    Output:
      FustDump/decompiled/*.lua   (when a decompiler function is exposed)
      FustDump/bytecode/*.luac    (always)
      FustDump/decomp_report.txt
]]

local MAX = 800
local SKIP = { CoreGui = true, CorePackages = true, ScriptContext = true, TestService = true }

local writefile, makefolder, isfolder = writefile, makefolder, isfolder
local game = game
local RS = game:GetService("ReplicatedStorage")

local function ensureDir(path)
    if not makefolder then return end
    local cur = ""
    for part in string.gmatch(path, "[^/]+") do
        cur = cur == "" and part or (cur .. "/" .. part)
        if not (isfolder and isfolder(cur)) then pcall(makefolder, cur) end
    end
end

local function write(p, t)
    if writefile then return pcall(writefile, p, t) end
end

local function sanitize(n)
    return tostring(n or "x"):gsub("[^%w%-%_%. ]", "_"):gsub("%s+", "_"):sub(1, 90)
end

local function full(inst)
    local ok, v = pcall(function() return inst:GetFullName() end)
    return ok and v or "?"
end

-- find a decompiler
local decompilerName, decompilerFn = nil, nil
for _, name in ipairs({
    "decompile", "psms", "decompile_luau", "luauDecompile", "decompileBytecode",
    "decompilebytecode", "decompiler", "luau_decompile", "LuraphDecompile",
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

if not getscriptbytecode then
    if messageboxasync or messagebox then
        pcall(messageboxasync or messagebox, "getscriptbytecode is not available in this executor.", "Pulsar.One", 48)
    end
    return
end

ensureDir("FustDump/bytecode")
ensureDir("FustDump/decompiled")

local index, decompIndex, report = { "path\tfile" }, { "path\tfile" }, {}
report[#report + 1] = "decompiler=" .. tostring(decompilerName or "none")

local count, decompCount = 0, 0
local seen = {}
local stack = {}

for _, svc in ipairs(game:GetChildren()) do
    if not SKIP[svc.Name] and not SKIP[svc.ClassName] then
        stack[#stack + 1] = svc
    end
end

while #stack > 0 and count < MAX do
    local inst = table.remove(stack)
    if inst and not seen[inst] then
        seen[inst] = true

        local ok, kids = pcall(function() return inst:GetChildren() end)
        if ok and kids then
            for i = #kids, 1, -1 do
                if not SKIP[kids[i].Name] then stack[#stack + 1] = kids[i] end
            end
        end

        local cn = inst.ClassName
        if cn == "LocalScript" or cn == "ModuleScript" or cn == "Script" then
            local ok2, code = pcall(getscriptbytecode, inst)
            if ok2 and type(code) == "string" and #code > 0 then
                count = count + 1
                if count % 50 == 0 then task.wait() end

                local base = string.format("%03d_%s", count, sanitize(inst.Name))
                local bfile = "FustDump/bytecode/" .. base .. ".luac"
                write(bfile, code)
                index[#index + 1] = full(inst) .. "\t" .. bfile

                if decompilerFn then
                    local ok3, src = pcall(decompilerFn, code)
                    if ok3 and type(src) == "string" and #src > 0 then
                        decompCount = decompCount + 1
                        local dfile = "FustDump/decompiled/" .. base .. ".lua"
                        write(dfile, src)
                        decompIndex[#decompIndex + 1] = full(inst) .. "\t" .. dfile
                    end
                end
            end
        end
    end
end

write("FustDump/bytecode/_index.txt", table.concat(index, "\n"))
write("FustDump/decompiled/_index.txt", table.concat(decompIndex, "\n"))
report[#report + 1] = "scripts=" .. tostring(count)
report[#report + 1] = "decompiled=" .. tostring(decompCount)
write("FustDump/decomp_report.txt", table.concat(report, "\n"))

if messageboxasync or messagebox then
    local box = messageboxasync or messagebox
    pcall(box, string.format(
        "Dumped %d scripts\nDecompiled: %d\nDecompiler: %s\n\nFustDump/bytecode + FustDump/decompiled",
        count, decompCount, tostring(decompilerName or "none (use PSMS UI)")
    ), "Pulsar.One Dumper", 48)
end
