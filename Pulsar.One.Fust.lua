--[[
    Pulsar.One - Fust Survival
    Undetected Drawing (UD) system — ScreenGui inside CoreGui
    Features: Player/NPC/Entity ESP, Silent Aim, Gun Mods, Speed/Fly, Chams,
    Skeleton ESP, Corner Boxes, Bullet Tracers, Hitmarkers, Hitsounds,
    Thirdperson, World Modulation, Staff List, Armour List, Keybind List
]]

if getgenv and getgenv().pulsarOne_loaded then
    return
end

local function __pulsarMain()
local RAND = tostring(math.random(100000, 999999))

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = workspace
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local Camera = Workspace.CurrentCamera
while not Camera do task.wait(0.1); Camera = Workspace.CurrentCamera end

-- Shortcuts
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait(0.1); LocalPlayer = Players.LocalPlayer end

if getgenv and not getgenv().pulsarFustFromLobby then
    local mb = messageboxasync or messagebox
    if type(mb) == "function" then
        pcall(mb, "Load Pulsar.One from the lobby.\n\nRun Pulsar.One.Fust.Lobby.lua in the lobby, click Load, then join a server.", "Pulsar.One", 48)
    end
    return
end

local function CoreParent()
    local ok, pg = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 5) end)
    if ok and pg then return pg end
    local ok2, hid = pcall(function() return gethui and gethui() end)
    if ok2 and hid then return hid end
    local ok3, core = pcall(function() return game:GetService("CoreGui") end)
    if ok3 and core then return core end
    return LocalPlayer:WaitForChild("PlayerGui")
end
local NpcsFolder = Workspace:FindFirstChild("Npcs")
local AnimalsFolder = Workspace:FindFirstChild("Animals")
local LootFolder = Workspace:FindFirstChild("Loot")
local NodesFolder = Workspace:FindFirstChild("Nodes")
local WorldItemsFolder = Workspace:FindFirstChild("WorldItems")
local AirdropsFolder = Workspace:FindFirstChild("Airdrops")
local PickupsFolder = Workspace:FindFirstChild("Pickups")
local MinicoptersFolder = Workspace:FindFirstChild("FustMinicopters")
local BoatsFolder = Workspace:FindFirstChild("FustBoats")
local DeployablesFolder = Workspace:FindFirstChild("Deployables")
local CameraFolder = Workspace:FindFirstChild("Camera")
local VMs = CameraFolder and CameraFolder:FindFirstChild("FustToolViewmodel")

local WORLD_READY = false
local function refreshWorldRefs()
    NpcsFolder = NpcsFolder or Workspace:FindFirstChild("Npcs")
    AnimalsFolder = AnimalsFolder or Workspace:FindFirstChild("Animals")
    LootFolder = LootFolder or Workspace:FindFirstChild("Loot")
    NodesFolder = NodesFolder or Workspace:FindFirstChild("Nodes")
    WorldItemsFolder = WorldItemsFolder or Workspace:FindFirstChild("WorldItems")
    AirdropsFolder = AirdropsFolder or Workspace:FindFirstChild("Airdrops")
    PickupsFolder = PickupsFolder or Workspace:FindFirstChild("Pickups")
    MinicoptersFolder = MinicoptersFolder or Workspace:FindFirstChild("FustMinicopters")
    BoatsFolder = BoatsFolder or Workspace:FindFirstChild("FustBoats")
    DeployablesFolder = DeployablesFolder or Workspace:FindFirstChild("Deployables")
    CameraFolder = CameraFolder or Workspace:FindFirstChild("Camera")
    if CameraFolder then VMs = VMs or CameraFolder:FindFirstChild("FustToolViewmodel") end
    if not WORLD_READY and NpcsFolder and NodesFolder and VMs then
        WORLD_READY = true
    end
    return WORLD_READY
end

task.spawn(function()
    while not WORLD_READY do
        pcall(refreshWorldRefs)
        task.wait(1)
    end
end)

-- ============================================================
-- CLONE FUNCTIONS (safe)
-- ============================================================
local clonefunc = clonefunction or function(f) return f end
local getrenv = getrenv or function() return _G end

local renv = getrenv()
local genv = (getgenv and getgenv()) or _G
local pi = math.pi
local huge = math.huge

local _color3new = clonefunc(renv.Color3.new)
local _instancenew = clonefunc(renv.Instance.new)

local function INew(class, props)
    local inst = _instancenew(class)
    if type(props) == "table" then
        local parent = props.Parent
        for k, v in pairs(props) do
            if k ~= "Parent" then
                pcall(function() inst[k] = v end)
            end
        end
        if parent then inst.Parent = parent end
    end
    return inst
end
local _mathatan2 = clonefunc(renv.math.atan2)
local _mathclamp = clonefunc(renv.math.clamp)
local _mathmax = clonefunc(renv.math.max)
local _setmetatable = clonefunc(renv.setmetatable)
local _typeof = clonefunc(renv.typeof)
local _taskspawn = clonefunc(renv.task and renv.task.spawn or task.spawn)
local _udim2fromoffset = clonefunc(renv.UDim2.fromOffset)
local _udim2new = clonefunc(renv.UDim2.new)
local _vector2new = clonefunc(renv.Vector2.new)
local _destroy = clonefunc(game.Destroy)
local _newcclosure = newcclosure or function(f) return f end
local _setreadonly = setreadonly or function() end

-- ============================================================
-- UD DRAWING SYSTEM
-- ScreenGui inside CoreGui
-- ============================================================
local NativeDrawing = _G.Drawing
local Drawing = {}
Drawing.Fonts = { UI = 0, System = 2, Plex = 1, Monospace = 3 }

local function updatePosition(frame, from, to, thickness)
    local central = (from + to) / 2
    local offset = to - from
    frame.Position = _udim2fromoffset(central.X, central.Y)
    frame.Rotation = _mathatan2(offset.Y, offset.X) * 180 / pi
    frame.Size = _udim2fromoffset(offset.Magnitude, _mathmax(thickness, 1))
end

local drawingDirectory
if not (NativeDrawing and type(NativeDrawing.new) == "function") then
drawingDirectory = INew("ScreenGui")
drawingDirectory.DisplayOrder = 15
drawingDirectory.IgnoreGuiInset = true
drawingDirectory.Name = "d" .. RAND
drawingDirectory.ResetOnSpawn = false
drawingDirectory.Enabled = true
drawingDirectory.Parent = CoreParent()
drawingDirectory.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
drawingDirectory.Enabled = true
drawingDirectory.DisplayOrder = 999
if getgenv then getgenv().pulsarDrawingDir = drawingDirectory end

-- Preload fonts so GetTextBoundsAsync doesn't yield in metamethods
local preloadedFonts = {
    Font.new("rbxasset://fonts/families/Arial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
    Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
    Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
    Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
}
for _, font in preloadedFonts do
    pcall(function()
        TextService:GetTextBoundsAsync(INew("GetTextBoundsParams", {
            Text = "Hi", Size = 12, Font = font, Width = huge
        }))
    end)
end
end

local itemCounter = 0
local cache = {}
local classes = {}

do
    -- LINE CLASS
    local line = {}
    function line.new()
        itemCounter = itemCounter + 1
        local id = itemCounter
        local obj = _setmetatable({
            _id = id, __OBJECT_EXISTS = true,
            _properties = {
                Color = _color3new(), From = _vector2new(), Thickness = 1,
                To = _vector2new(), Transparency = 1, Visible = false, ZIndex = 0
            },
            _frame = INew("Frame", {
                Name = tostring(id), AnchorPoint = _vector2new(0.5, 0.5),
                BackgroundColor3 = _color3new(), BorderSizePixel = 0,
                Parent = drawingDirectory, Position = _udim2new(),
                Size = _udim2new(), Visible = false, ZIndex = 0
            })
        }, line)
        cache[id] = obj
        return obj
    end
    function line:__index(k)
        local p = self._properties[k]
        if p ~= nil then return p end
        return line[k]
    end
    function line:__newindex(k, v)
        if self.__OBJECT_EXISTS ~= true then return end
        local p = self._properties
        if p[k] == nil or p[k] == v or _typeof(p[k]) ~= _typeof(v) then return end
        p[k] = v
        if k == "Color" then
            self._frame.BackgroundColor3 = v
        elseif k == "From" or k == "To" then
            self:_updatePosition()
        elseif k == "Thickness" then
            self._frame.Size = _udim2fromoffset(self._frame.AbsoluteSize.X, _mathmax(v, 1))
        elseif k == "Transparency" then
            self._frame.BackgroundTransparency = _mathclamp(v, 0, 1)
        elseif k == "Visible" then
            self._frame.Visible = v
        elseif k == "ZIndex" then
            self._frame.ZIndex = v
        end
    end
    function line:__iter() return next, self._properties end
    function line:__tostring() return "Drawing" end
    function line:Destroy() cache[self._id] = nil; self.__OBJECT_EXISTS = false; _destroy(self._frame) end
    function line:_updatePosition() local p = self._properties; updatePosition(self._frame, p.From, p.To, p.Thickness) end
    line.Remove = line.Destroy
    classes.Line = line
end

do
    -- CIRCLE CLASS
    local circle = {}
    function circle.new()
        itemCounter = itemCounter + 1
        local id = itemCounter
        local frame = INew("Frame", {
            Name = tostring(id), AnchorPoint = _vector2new(0.5, 0.5),
            BackgroundColor3 = _color3new(), BackgroundTransparency = 1,
            BorderSizePixel = 0, Parent = drawingDirectory,
            Position = _udim2new(), Size = _udim2new(), Visible = false, ZIndex = 0
        })
        INew("UICorner", { Name = "_corner", CornerRadius = UDim.new(1, 0), Parent = frame })
        INew("UIStroke", { Name = "_stroke", Color = _color3new(), Thickness = 1, Parent = frame })
        local obj = _setmetatable({
            _id = id, __OBJECT_EXISTS = true,
            _properties = {
                Color = _color3new(), Filled = false, NumSides = 0,
                Position = _vector2new(), Radius = 0, Thickness = 1,
                Transparency = 1, Visible = false, ZIndex = 0
            },
            _frame = frame
        }, circle)
        cache[id] = obj
        return obj
    end
    function circle:__index(k) local p = self._properties[k]; if p ~= nil then return p end; return circle[k] end
    function circle:__newindex(k, v)
        if self.__OBJECT_EXISTS ~= true then return end
        local p = self._properties
        if p[k] == nil or p[k] == v or _typeof(p[k]) ~= _typeof(v) then return end
        p[k] = v
        if k == "Color" then self._frame.BackgroundColor3 = v; self._frame._stroke.Color = v
        elseif k == "Filled" then self._frame.BackgroundTransparency = v and _mathclamp(p.Transparency, 0, 1) or 1
        elseif k == "Position" then self._frame.Position = _udim2fromoffset(v.X, v.Y)
        elseif k == "Radius" then self:_updateRadius()
        elseif k == "Thickness" then self._frame._stroke.Thickness = _mathmax(v, 1); self:_updateRadius()
        elseif k == "Transparency" then self._frame._stroke.Transparency = _mathclamp(v, 0, 1); if p.Filled then self._frame.BackgroundTransparency = _mathclamp(v, 0, 1) end
        elseif k == "Visible" then self._frame.Visible = v
        elseif k == "ZIndex" then self._frame.ZIndex = v end
    end
    function circle:__iter() return next, self._properties end
    function circle:__tostring() return "Drawing" end
    function circle:Destroy() cache[self._id] = nil; self.__OBJECT_EXISTS = false; _destroy(self._frame) end
    function circle:_updateRadius() local p = self._properties; local d = (p.Radius * 2) - (p.Thickness * 2); self._frame.Size = _udim2fromoffset(d, d) end
    circle.Remove = circle.Destroy
    classes.Circle = circle
end

do
    -- TEXT CLASS
    local text = {}
    local enumToFont = {
        [Drawing.Fonts.UI] = Font.new("rbxasset://fonts/families/Arial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
        [Drawing.Fonts.System] = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
        [Drawing.Fonts.Plex] = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
        [Drawing.Fonts.Monospace] = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
    }
    function text.new()
        itemCounter = itemCounter + 1
        local id = itemCounter
        local frame = INew("TextLabel", {
            Name = tostring(id), BackgroundTransparency = 1,
            FontFace = enumToFont[0], Parent = drawingDirectory,
            Position = _udim2new(), Size = _udim2new(),
            Text = "", TextColor3 = _color3new(), TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Visible = false, ZIndex = 0
        })
        INew("UIStroke", { Name = "_stroke", Color = _color3new(), Enabled = false, Thickness = 1, Parent = frame })
        local obj = _setmetatable({
            _id = id, __OBJECT_EXISTS = true,
            _properties = {
                Center = false, Color = _color3new(), Font = 0,
                Outline = false, OutlineColor = _color3new(),
                Position = _vector2new(), Size = 12, Text = "",
                TextBounds = _vector2new(), Transparency = 1,
                Visible = false, ZIndex = 0
            },
            _frame = frame
        }, text)
        cache[id] = obj
        return obj
    end
    function text:__index(k) if k == "Loaded" then return self._frame.IsLoaded end; local p = self._properties[k]; if p ~= nil then return p end; return text[k] end
    function text:__newindex(k, v)
        if self.__OBJECT_EXISTS ~= true then return end
        local p = self._properties
        if k == "TextBounds" or p[k] == nil or p[k] == v or _typeof(p[k]) ~= _typeof(v) then return end
        p[k] = v
        if k == "Center" then self._frame.TextXAlignment = v and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
        elseif k == "Color" then self._frame.TextColor3 = v
        elseif k == "Font" then self._frame.FontFace = enumToFont[v] or enumToFont[0]; self:_updateTextBounds()
        elseif k == "Outline" then self._frame._stroke.Enabled = v
        elseif k == "OutlineColor" then self._frame._stroke.Color = v
        elseif k == "Position" then self._frame.Position = _udim2fromoffset(v.X, v.Y)
        elseif k == "Size" then self._frame.TextSize = v; self:_updateTextBounds()
        elseif k == "Text" then self._frame.Text = v; self:_updateTextBounds()
        elseif k == "Transparency" then self._frame.TextTransparency = _mathclamp(v, 0, 1); self._frame._stroke.Transparency = _mathclamp(v, 0, 1)
        elseif k == "Visible" then self._frame.Visible = v
        elseif k == "ZIndex" then self._frame.ZIndex = v end
    end
    function text:__iter() return next, self._properties end
    function text:__tostring() return "Drawing" end
    function text:Destroy() cache[self._id] = nil; self.__OBJECT_EXISTS = false; _destroy(self._frame) end
    function text:_updateTextBounds()
        local p = self._properties
        p.TextBounds = TextService:GetTextBoundsAsync(INew("GetTextBoundsParams", {
            Text = p.Text, Size = p.Size, Font = enumToFont[p.Font] or enumToFont[0], Width = huge
        }))
    end
    text.Remove = text.Destroy
    classes.Text = text
end

do
    -- SQUARE CLASS
    local square = {}
    function square.new()
        itemCounter = itemCounter + 1
        local id = itemCounter
        local frame = INew("Frame", {
            BackgroundColor3 = _color3new(), BackgroundTransparency = 1,
            BorderSizePixel = 0, Parent = drawingDirectory,
            Position = _udim2new(), Size = _udim2new(), Visible = false, ZIndex = 0
        })
        INew("UIStroke", { Name = "_stroke", Color = _color3new(), Thickness = 1, LineJoinMode = Enum.LineJoinMode.Miter, Parent = frame })
        local obj = _setmetatable({
            _id = id, __OBJECT_EXISTS = true,
            _properties = {
                Color = _color3new(), Filled = false,
                Position = _vector2new(), Size = _vector2new(),
                Thickness = 1, Transparency = 1, Visible = false, ZIndex = 0
            },
            _frame = frame
        }, square)
        cache[id] = obj
        return obj
    end
    function square:__index(k) local p = self._properties[k]; if p ~= nil then return p end; return square[k] end
    function square:__newindex(k, v)
        if self.__OBJECT_EXISTS ~= true then return end
        local p = self._properties
        if p[k] == nil or p[k] == v or _typeof(p[k]) ~= _typeof(v) then return end
        p[k] = v
        if k == "Color" then self._frame.BackgroundColor3 = v; self._frame._stroke.Color = v
        elseif k == "Filled" then self._frame.BackgroundTransparency = v and _mathclamp(p.Transparency, 0, 1) or 1
        elseif k == "Position" or k == "Size" then self:_updateScale()
        elseif k == "Thickness" then self._frame._stroke.Thickness = v; self:_updateScale()
        elseif k == "Transparency" then self._frame._stroke.Transparency = _mathclamp(v, 0, 1); if p.Filled then self._frame.BackgroundTransparency = _mathclamp(v, 0, 1) end
        elseif k == "Visible" then self._frame.Visible = v
        elseif k == "ZIndex" then self._frame.ZIndex = v end
    end
    function square:__iter() return next, self._properties end
    function square:__tostring() return "Drawing" end
    function square:Destroy() cache[self._id] = nil; self.__OBJECT_EXISTS = false; _destroy(self._frame) end
    function square:_updateScale()
        local p = self._properties
        self._frame.Position = _udim2fromoffset(p.Position.X + p.Thickness, p.Position.Y + p.Thickness)
        self._frame.Size = _udim2fromoffset(p.Size.X - p.Thickness * 2, p.Size.Y - p.Thickness * 2)
    end
    square.Remove = square.Destroy
    classes.Square = square
end

if NativeDrawing and type(NativeDrawing.new) == "function" then
    -- executor Drawing API: lives outside the DataModel, invisible to the game
    Drawing.new = function(x)
        return NativeDrawing.new(x)
    end
    Drawing.clear = function()
        if type(NativeDrawing.clear) == "function" then
            pcall(NativeDrawing.clear)
        end
    end
else
    Drawing.new = _newcclosure(function(x)
        assert(classes[x], string.format("Invalid drawing type '%s'", x))
        return classes[x].new()
    end)
    Drawing.clear = _newcclosure(function()
        for _, v in cache do
            if v.__OBJECT_EXISTS then v:Destroy() end
        end
    end)
end

Drawing.cache = cache
_setreadonly(Drawing, true)
_setreadonly(Drawing.Fonts, true)

-- ============================================================
-- CONFIGURATION (Flags)
-- ============================================================
local Flags = {}
local FlagListeners = {}
local function SetFlag(name, value)
    Flags[name] = value
    local listeners = FlagListeners[name]
    if listeners then
        for _, fn in listeners do pcall(fn, value) end
    end
end
local function GetFlag(name, default) return Flags[name] ~= nil and Flags[name] or default end
local function OnFlag(name, fn)
    FlagListeners[name] = FlagListeners[name] or {}
    table.insert(FlagListeners[name], fn)
end

-- Player ESP
SetFlag("playerEsp_toggle", false); SetFlag("playerEsp_teamCheck", true)
SetFlag("playerEsp_name", false); SetFlag("playerEsp_box", false)
SetFlag("playerEsp_healthbar", false); SetFlag("playerEsp_distance", false)
SetFlag("playerEsp_weapon", false); SetFlag("playerEsp_skeleton", false)
SetFlag("playerEsp_cornerBox", false); SetFlag("playerEsp_tracers", false)
SetFlag("playerChams_toggle", false)
SetFlag("playerChams_colour", Color3.fromRGB(200,0,255))
SetFlag("playerChams_transparency", 50)
SetFlag("playerEsp_nameColour", Color3.fromRGB(255,255,255))
SetFlag("playerEsp_boxColour", Color3.fromRGB(255,255,255))
SetFlag("playerEsp_distanceColour", Color3.fromRGB(255,255,255))
SetFlag("playerEsp_weaponColour", Color3.fromRGB(255,255,255))

-- NPC ESP
SetFlag("npcEsp_toggle", false); SetFlag("npcEsp_name", false)
SetFlag("npcEsp_box", false); SetFlag("npcEsp_healthbar", false)
SetFlag("npcEsp_distance", false); SetFlag("npcEsp_skeleton", false)
SetFlag("npcEsp_scav", false); SetFlag("npcEsp_bruno", false)
SetFlag("npcEsp_boris", false); SetFlag("npcEsp_brutus", false)
SetFlag("npcEsp_bradley", false); SetFlag("npcEsp_wolf", false)
SetFlag("npcEsp_deer", false); SetFlag("npcEsp_boar", false)
SetFlag("npcEsp_zombie", false); SetFlag("npcEsp_maxDistance", 7500)
SetFlag("npcEsp_attackHeli", false)
SetFlag("npcEsp_scavColour", Color3.fromRGB(62,87,55))
SetFlag("npcEsp_brunoColour", Color3.fromRGB(81,99,40))
SetFlag("npcEsp_borisColour", Color3.fromRGB(21,26,10))
SetFlag("npcEsp_brutusColour", Color3.fromRGB(38,41,33))
SetFlag("npcEsp_bradleyColour", Color3.fromRGB(39,49,16))
SetFlag("npcEsp_attackHeliColour", Color3.fromRGB(120,50,40))
SetFlag("npcEsp_wolfColour", Color3.fromRGB(105,95,68))
SetFlag("npcEsp_deerColour", Color3.fromRGB(63,57,41))
SetFlag("npcEsp_boarColour", Color3.fromRGB(43,35,13))
SetFlag("npcEsp_zombieColour", Color3.fromRGB(50,100,50))

-- Entity ESP
SetFlag("entityEsp_toggle", false); SetFlag("entityEsp_box", false)
SetFlag("entityEsp_name", false); SetFlag("entityEsp_distance", false)
SetFlag("entityEsp_minicopter", false); SetFlag("entityEsp_bodyBag", false)
SetFlag("entityEsp_airdrop", false); SetFlag("entityEsp_timedCrate", false)
SetFlag("entityEsp_hemp", false); SetFlag("entityEsp_stone", false)
SetFlag("entityEsp_phosphate", false); SetFlag("entityEsp_metal", false)
SetFlag("entityEsp_commonGift", false); SetFlag("entityEsp_rareGift", false)
SetFlag("entityEsp_maxDistance", 7500)
SetFlag("entityEsp_hempColour", Color3.fromRGB(168,168,168))
SetFlag("entityEsp_stoneColour", Color3.fromRGB(87,87,87))
SetFlag("entityEsp_phosphateColour", Color3.fromRGB(235,229,158))
SetFlag("entityEsp_metalColour", Color3.fromRGB(145,85,62))
SetFlag("entityEsp_sulfur", false); SetFlag("entityEsp_sulfurColour", Color3.fromRGB(230,220,60))
SetFlag("entityEsp_ore", false); SetFlag("entityEsp_oreColour", Color3.fromRGB(190,120,80))
SetFlag("entityEsp_tree", false); SetFlag("entityEsp_treeColour", Color3.fromRGB(70,130,60))
SetFlag("entityEsp_cactus", false); SetFlag("entityEsp_cactusColour", Color3.fromRGB(60,150,80))
SetFlag("entityEsp_barrel", false); SetFlag("entityEsp_barrelColour", Color3.fromRGB(90,140,200))
SetFlag("entityEsp_barrelRed", false); SetFlag("entityEsp_barrelRedColour", Color3.fromRGB(220,60,60))
SetFlag("entityEsp_lootCrate", false); SetFlag("entityEsp_lootCrateColour", Color3.fromRGB(200,160,80))
SetFlag("entityEsp_lootSack", false); SetFlag("entityEsp_lootSackColour", Color3.fromRGB(180,170,120))
SetFlag("entityEsp_militaryCrate", false); SetFlag("entityEsp_militaryCrateColour", Color3.fromRGB(120,140,80))
SetFlag("entityEsp_worldItem", false); SetFlag("entityEsp_worldItemColour", Color3.fromRGB(255,255,255))
SetFlag("entityEsp_boat", false); SetFlag("entityEsp_boatColour", Color3.fromRGB(80,180,220))
SetFlag("entityEsp_pickup", false); SetFlag("entityEsp_pickupColour", Color3.fromRGB(255,215,15))
SetFlag("npcEsp_soldier", false); SetFlag("npcEsp_soldierColour", Color3.fromRGB(62,87,55))
SetFlag("npcEsp_bear", false); SetFlag("npcEsp_bearColour", Color3.fromRGB(105,80,60))
SetFlag("entityEsp_loot", false); SetFlag("entityEsp_lootColour", Color3.fromRGB(220,220,120))
SetFlag("entityEsp_lockedCrate", false); SetFlag("entityEsp_lockedCrateColour", Color3.fromRGB(255,80,80))
SetFlag("entityEsp_chest", false); SetFlag("entityEsp_chestColour", Color3.fromRGB(200,140,60))
SetFlag("entityEsp_deployable", false); SetFlag("entityEsp_deployableColour", Color3.fromRGB(150,150,255))
SetFlag("entityEsp_node", false); SetFlag("entityEsp_nodeColour", Color3.fromRGB(120,200,120))
SetFlag("desync_toggle", false)
SetFlag("entityEsp_bodyBagColour", Color3.fromRGB(255,101,40))
SetFlag("entityEsp_airdropColour", Color3.fromRGB(80,49,20))
SetFlag("entityEsp_timedCrateColour", Color3.fromRGB(41,41,41))
SetFlag("entityEsp_commonGiftColour", Color3.fromRGB(220,220,220))
SetFlag("entityEsp_rareGiftColour", Color3.fromRGB(40,110,255))
SetFlag("entityEsp_minicopterColour", Color3.fromRGB(44,236,19))
SetFlag("xray_toggle", false); SetFlag("xray_transparency", 70)
SetFlag("disableTraps_toggle", false); SetFlag("disableSpikes_toggle", false)
SetFlag("silentMinicopter_toggle", false); SetFlag("disableMinicopterDamage_toggle", false)
SetFlag("playerEsp_skeletonColour", Color3.fromRGB(255,255,255))
SetFlag("localWeaponChams_colour", Color3.fromRGB(255,0,255))
SetFlag("localArmChams_colour", Color3.fromRGB(0,100,255))

-- Silent Aim
SetFlag("silentAim_toggle", false); SetFlag("silentAim_hitchance", 100)
SetFlag("silentAim_hitpart", "head"); SetFlag("silentAim_targetNpcs", true)
SetFlag("silentAim_teamCheck", true); SetFlag("silentAim_prediction", true)
SetFlag("silentAim_visibleCheck", false); SetFlag("silentAim_dynamicFov", true)
SetFlag("silentAim_drawFov", false); SetFlag("silentAim_fovSize", 205)
SetFlag("silentAim_instantHit", false); SetFlag("silentAim_manipulation", false)
SetFlag("silentAim_manipulationDistance", 8); SetFlag("silentAim_hitscan", false)
SetFlag("silentAim_hitscanDistance", 8.5); SetFlag("silentAim_snapline", false)
SetFlag("silentAim_manipulationIndicator", false)
SetFlag("silentAim_hitscanIndicator", false)
SetFlag("silentAim_manipulationIndicatorColour", Color3.fromRGB(255,0,255))
SetFlag("silentAim_hitscanIndicatorColour", Color3.fromRGB(255,196,0))
SetFlag("silentAim_snaplineColour", Color3.fromRGB(255,0,255))
SetFlag("silentAim_fovColour", Color3.fromRGB(255,0,255))

-- Aimbot (normal camera aim, mouse-held)
SetFlag("aimbot_toggle", false)
SetFlag("aimbot_fov", 250)
SetFlag("aimbot_smoothing", 5)
SetFlag("aimbot_prediction", true)
SetFlag("silentAim_toggle", false)
SetFlag("silentAim_hitchance", 100)
SetFlag("silentAim_instantHit", false)
SetFlag("silentAim_manipulation", false)
SetFlag("silentAim_manipulationDistance", 8)
SetFlag("desync_toggle", false)
SetFlag("desync_angle", 90)
SetFlag("emote_sel", "Zombie")

-- Gun Mods
SetFlag("gunMods_recoilPercentage", 100); SetFlag("gunMods_spreadPercentage", 0)
SetFlag("gunMods_firerateMultiplier", 1.8); SetFlag("fullyAutomatic_toggle", false)
SetFlag("noMeleeShake_toggle", false); SetFlag("increaseMeleeSpeed_toggle", false)
SetFlag("increaseMeleeSpeed_amount", 1); SetFlag("increaseMeleeRange_toggle", false)
SetFlag("increaseMeleeRange_amount", 1); SetFlag("instantEoka_toggle", false)
SetFlag("alwaysShoot_toggle", false); SetFlag("autoReload_toggle", false)
SetFlag("bulletTp_toggle", false)

-- Local
SetFlag("speedHack_toggle", false); SetFlag("speedHack_amount", 21)
SetFlag("fly_toggle", false); SetFlag("fly_speed", 21)
SetFlag("antiaim_toggle", false); SetFlag("antiaim_depth", 2)
SetFlag("noFallDamage_toggle", false); SetFlag("alwaysCriticals_toggle", false)
SetFlag("instantEquip_toggle", false); SetFlag("silentWalk_toggle", false)
SetFlag("instantLoot_toggle", false)
SetFlag("localChams_toggle", false); SetFlag("localChams_colour", Color3.fromRGB(255,0,255))
SetFlag("localChams_transparency", 59); SetFlag("localChams_material", "forcefield")
SetFlag("localWeaponChams_toggle", false)
SetFlag("localArmChams_toggle", false)
SetFlag("fovChanger_toggle", false); SetFlag("fovChanger_amount", 120)
SetFlag("zoom_toggle", false); SetFlag("zoom_amount", 20)
SetFlag("freecam_toggle", false); SetFlag("freecam_speed", 131)
SetFlag("thirdperson_toggle", false); SetFlag("thirdperson_distance", 10)

-- World Modulation (UD)
SetFlag("ambient_toggle", false); SetFlag("ambient_colour", Color3.fromRGB(255,255,255))
SetFlag("removeGrass_toggle", false); SetFlag("noFog_toggle", false)
SetFlag("timeOfDay", 12); SetFlag("timeOfDay_toggle", false)

-- Misc
SetFlag("staffDetector_toggle", false); SetFlag("keybindList_toggle", false)
SetFlag("targetHud_toggle", false); SetFlag("suicide_toggle", false)
SetFlag("resolveAntiAim_toggle", false); SetFlag("combatMode_toggle", false)
SetFlag("streamer_toggle", false)
SetFlag("streamer_selfName", "")
SetFlag("streamer_elseName", "")
SetFlag("bulletTracers_toggle", false); SetFlag("hitmarkers_toggle", false)
SetFlag("hitsounds_toggle", false); SetFlag("hitsoundType", "sine_click")
SetFlag("hitmarkers_toggle", false); SetFlag("hitmarker_colour", Color3.fromRGB(255,255,255))

-- ============================================================
-- NPC/ANIMAL PATHS (Fust dump)
-- ============================================================
local NPC_SETTINGS = {
    Soldier = { name = "soldier", flag = "soldier", colour = Color3.fromRGB(62,87,55) },
    Deer = { name = "deer", flag = "deer", colour = Color3.fromRGB(63,57,41) },
    Bear = { name = "bear", flag = "bear", colour = Color3.fromRGB(105,80,60) },
    Boar = { name = "boar", flag = "boar", colour = Color3.fromRGB(43,35,13) },
}

local ENTITY_SETTINGS = {
    StoneNode = { name = "stone", flag = "stone", colour = Color3.fromRGB(87,87,87) },
    SulfurNode = { name = "sulfur", flag = "sulfur", colour = Color3.fromRGB(230,220,60) },
    MetalNode = { name = "metal", flag = "metal", colour = Color3.fromRGB(145,85,62) },
    NodeOre = { name = "ore", flag = "ore", colour = Color3.fromRGB(190,120,80) },
    Tree = { name = "tree", flag = "tree", colour = Color3.fromRGB(70,130,60) },
    Cactus = { name = "cactus", flag = "cactus", colour = Color3.fromRGB(60,150,80) },
    LootBarrel = { name = "barrel", flag = "barrel", colour = Color3.fromRGB(90,140,200) },
    LootBarrelRed = { name = "barrel red", flag = "barrelRed", colour = Color3.fromRGB(220,60,60) },
    LootCrate = { name = "loot crate", flag = "lootCrate", colour = Color3.fromRGB(200,160,80) },
    LootSack = { name = "loot sack", flag = "lootSack", colour = Color3.fromRGB(180,170,120) },
    MilitaryCrate = { name = "military crate", flag = "militaryCrate", colour = Color3.fromRGB(120,140,80) },
    Item = { name = "world item", flag = "worldItem", colour = Color3.fromRGB(255,255,255) },
    Airdrop = { name = "airdrop", flag = "airdrop", colour = Color3.fromRGB(255,140,40) },
    Minicopter = { name = "minicopter", flag = "minicopter", colour = Color3.fromRGB(44,236,19) },
    Boat = { name = "boat", flag = "boat", colour = Color3.fromRGB(80,180,220) },
    Pickup = { name = "pickup", flag = "pickup", colour = Color3.fromRGB(255,215,15) },
    LockedCrate = { name = "locked crate", flag = "lockedCrate", colour = Color3.fromRGB(255,80,80) },
    ToolCupboard = { name = "tool cupboard", flag = "chest", colour = Color3.fromRGB(200,140,60) },
    LargeBox = { name = "large box", flag = "chest", colour = Color3.fromRGB(200,140,60) },
    WoodenBox = { name = "wooden box", flag = "chest", colour = Color3.fromRGB(200,140,60) },
    Shelves = { name = "shelves", flag = "chest", colour = Color3.fromRGB(200,140,60) },
    Loot = { name = "loot", flag = "loot", colour = Color3.fromRGB(220,220,120) },
}

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================
local function WorldToScreen(point)
    local pos, onScreen = Camera:WorldToViewportPoint(point)
    return Vector2.new(pos.X, pos.Y), onScreen, pos.Z
end

local function GetCharacterRoot(character)
    return character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
end

local function GetHealth(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then return humanoid.Health, humanoid.MaxHealth end
    return 0, 100
end

local function GetWeaponName(character)    if not character then return "none" end
    -- No remote calls: only read replicated children (UD-safe)
    for _, child in character:GetChildren() do
        if child:IsA("Tool") then
            return child.Name
        end
    end
    local backpack = LocalPlayer and LocalPlayer:FindFirstChild("Backpack")
    if backpack and character == LocalPlayer.Character then
        for _, tool in backpack:GetChildren() do
            if tool:IsA("Tool") then return tool.Name end
        end
    end
    return "none"
end

-- ============================================================
-- PERSISTENT ESP OBJECTS (created once, updated per frame)
-- ============================================================
local playerESPObjects = {}
local npcESPObjects = {}
local entityESPObjects = {}

local function CreatePlayerESPObjects()
    return {
        box = Drawing.new("Square"),
        nameText = Drawing.new("Text"),
        distText = Drawing.new("Text"),
        weaponText = Drawing.new("Text"),
        healthBar = Drawing.new("Square"),
        healthBarBg = Drawing.new("Square"),
        cornerTL = Drawing.new("Line"), cornerTR = Drawing.new("Line"),
        cornerBL = Drawing.new("Line"), cornerBR = Drawing.new("Line"),
        cornerTLa = Drawing.new("Line"), cornerTLb = Drawing.new("Line"),
        cornerTRa = Drawing.new("Line"), cornerTRb = Drawing.new("Line"),
        cornerBLa = Drawing.new("Line"), cornerBLb = Drawing.new("Line"),
        cornerBRa = Drawing.new("Line"), cornerBRb = Drawing.new("Line"),
        tracer = Drawing.new("Line"),
        skeletonLines = {},
    }
end

local function CreateNPCObjects()
    return {
        box = Drawing.new("Square"),
        nameText = Drawing.new("Text"),
        distText = Drawing.new("Text"),
        healthBar = Drawing.new("Square"),
        healthBarBg = Drawing.new("Square"),
    }
end

local function CreateEntityObjects()
    return {
        box = Drawing.new("Square"),
        nameText = Drawing.new("Text"),
        distText = Drawing.new("Text"),
    }
end

-- ============================================================
-- CHAMS SYSTEM (Local Player)
-- ============================================================
-- CHAMS SYSTEM (Local Player)
-- ============================================================
local chamsCache = {}
local weaponChamsCache = {}
local armChamsCache = {}
local MATERIAL_MAP = {
    forcefield = Enum.Material.ForceField,
    neon = Enum.Material.Neon,
    smoothplastic = Enum.Material.SmoothPlastic,
    glass = Enum.Material.Glass,
    ice = Enum.Material.Ice,
}

local function applyChamsTo(part, cache, colour, transparency, material)
    if not part then return end
    cache[part] = { Color = part.Color, Material = part.Material, Transparency = part.Transparency }
    part.Color = colour or Color3.fromRGB(255, 0, 255)
    part.Transparency = (transparency or 50) / 100
    part.Material = MATERIAL_MAP[material or "forcefield"] or Enum.Material.ForceField
end

local function revertChamsFrom(part, cache)
    local original = cache[part]
    if original and part and part.Parent then
        part.Color = original.Color
        part.Material = original.Material
        part.Transparency = original.Transparency
    end
    cache[part] = nil
end

local lastChamsUpdate = 0
local function UpdateLocalChams()
    local now = os.clock()
    if now - lastChamsUpdate < 0.2 then return end
    lastChamsUpdate = now
    local character = LocalPlayer.Character

    -- Body chams
    if character and GetFlag("localChams_toggle") then
        for _, part in character:GetChildren() do
            if part:IsA("BasePart") and part.Transparency < 1 and not chamsCache[part] then
                applyChamsTo(part, chamsCache, GetFlag("localChams_colour"), GetFlag("localChams_transparency"), GetFlag("localChams_material"))
            end
        end
    else
        for part in chamsCache do
            if part and part.Parent then revertChamsFrom(part, chamsCache) end
        end
    end

    -- Arms + weapon chams (same viewmodel path, split by part name)
    if VMs then
        for _, vmPart in VMs:GetDescendants() do
            if vmPart:IsA("BasePart") and vmPart.Transparency < 1 then
                local n = vmPart.Name:lower()
                local isArm = n:find("arm") ~= nil or n:find("hand") ~= nil
                if isArm then
                    if GetFlag("localArmChams_toggle") then
                        if not armChamsCache[vmPart] then
                            applyChamsTo(vmPart, armChamsCache, GetFlag("localArmChams_colour", Color3.fromRGB(0,120,255)), GetFlag("localChams_transparency"), GetFlag("localChams_material"))
                        end
                    elseif armChamsCache[vmPart] then
                        revertChamsFrom(vmPart, armChamsCache)
                    end
                else
                    if GetFlag("localWeaponChams_toggle") then
                        if not weaponChamsCache[vmPart] then
                            applyChamsTo(vmPart, weaponChamsCache, GetFlag("localWeaponChams_colour", Color3.fromRGB(255,0,255)), GetFlag("localChams_transparency"), GetFlag("localChams_material"))
                        end
                    elseif weaponChamsCache[vmPart] then
                        revertChamsFrom(vmPart, weaponChamsCache)
                    end
                end
            end
        end
    end
    if not GetFlag("localArmChams_toggle") then
        for part in armChamsCache do
            if part and part.Parent then revertChamsFrom(part, armChamsCache) end
        end
    end
    if not GetFlag("localWeaponChams_toggle") then
        for part in weaponChamsCache do
            if part and part.Parent then revertChamsFrom(part, weaponChamsCache) end
        end
    end
end

-- ============================================================
-- PLAYER CHAMS (same method as local chams)
-- ============================================================
local playerChamsCache = setmetatable({}, { __mode = "k" })
local lastPlayerChams = 0

local function UpdatePlayerChams()
    local now = os.clock()
    if now - lastPlayerChams < 0.2 then return end
    lastPlayerChams = now

    if GetFlag("playerChams_toggle") then
        local colour = GetFlag("playerChams_colour", Color3.fromRGB(200,0,255))
        local transp = GetFlag("playerChams_transparency", 50)
        local matName = GetFlag("localChams_material", "forcefield")
        local material = MATERIAL_MAP[matName] or Enum.Material.ForceField
        local seen = {}

        for _, plr in Players:GetPlayers() do
            if plr ~= LocalPlayer then
                local char = plr.Character
                if char then
                    seen[char] = true
                    local cache = playerChamsCache[char]
                    if not cache then cache = {}; playerChamsCache[char] = cache end
                    for _, part in char:GetChildren() do
                        if part:IsA("BasePart") and part.Transparency < 1 and not cache[part] then
                            cache[part] = { Color = part.Color, Material = part.Material, Transparency = part.Transparency }
                            part.Color = colour
                            part.Transparency = transp / 100
                            part.Material = material
                        end
                    end
                end
            end
        end

        for char, cache in playerChamsCache do
            if not seen[char] or not char.Parent then
                for part, orig in cache do
                    if part and part.Parent then
                        part.Color = orig.Color
                        part.Material = orig.Material
                        part.Transparency = orig.Transparency
                    end
                end
                playerChamsCache[char] = nil
            end
        end
    else
        for char, cache in playerChamsCache do
            for part, orig in cache do
                if part and part.Parent then
                    part.Color = orig.Color
                    part.Material = orig.Material
                    part.Transparency = orig.Transparency
                end
            end
            playerChamsCache[char] = nil
        end
    end
end

-- ============================================================
-- BULLET TRACERS
-- ============================================================
local function CreateBulletTracer(origin, destination)
    if not GetFlag("bulletTracers_toggle") then return end
    local fromPos, fromVis = WorldToScreen(origin)
    local toPos, toVis = WorldToScreen(destination)
    if not fromVis or not toVis then return end
    local line = Drawing.new("Line")
    line.From = fromPos
    line.To = toPos
    line.Color = Color3.fromRGB(255, 255, 200)
    line.Thickness = 1
    line.Transparency = 0.3
    line.Visible = true
    line.ZIndex = 10
    _taskspawn(function()
        for i = 0.3, 1, 0.05 do
            if line and line.Visible then line.Transparency = i end
            task.wait(0.02)
        end
        if line then line:Remove() end
    end)
end

-- ============================================================
-- HITMARKERS
-- ============================================================
local function DrawHitmarker()
    if not GetFlag("hitmarkers_toggle") then return end
    local center = Camera.ViewportSize / 2
    local size, gap = 8, 3
    local color = GetFlag("hitmarker_colour", Color3.fromRGB(255,255,255))
    local lines = {
        {center + Vector2.new(-size,-size), center + Vector2.new(-gap,-gap)},
        {center + Vector2.new(size,-size),  center + Vector2.new(gap,-gap)},
        {center + Vector2.new(-size,size),  center + Vector2.new(-gap,gap)},
        {center + Vector2.new(size,size),   center + Vector2.new(gap,gap)},
    }
    for _, l in lines do
        local line = Drawing.new("Line")
        line.From = l[1]; line.To = l[2]
        line.Color = color; line.Thickness = 2
        line.Transparency = 0; line.Visible = true; line.ZIndex = 20
        task.delay(0.1, function() if line then line:Remove() end end)
    end
end

-- ============================================================
-- HITSOUNDS
-- ============================================================
local hitSoundIds = {
    sine_click = "rbxassetid://850534677",
    bell = "rbxassetid://850534677",
    bubble = "rbxassetid://6042603527",
    knock = "rbxassetid://5098017487",
}

local function PlayHitSound()
    if not GetFlag("hitsounds_toggle") then return end
    local id = hitSoundIds[GetFlag("hitsoundType")] or hitSoundIds.sine_click
    local sound = Instance.new("Sound")
    sound.SoundId = id; sound.Volume = 0.5; sound.Parent = Workspace
    sound:Play()
    sound.Ended:Connect(function() sound:Destroy() end)
end

-- ============================================================
-- THIRDPERSON / FREECAM
-- ============================================================
local freecamCam = nil
local tpYaw, tpPitch = nil, 0

local function ThirdpersonReset()
    local rx, ry = Camera.CFrame:ToOrientation()
    tpPitch = rx
    tpYaw = ry
end

local function UpdateThirdperson()
    if not GetFlag("thirdperson_toggle") then return end
    local character = LocalPlayer.Character
    if not character then return end
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if not head then return end
    if tpYaw == nil then ThirdpersonReset() end
    local dist = GetFlag("thirdperson_distance", 10)
    Camera.CameraType = Enum.CameraType.Scriptable
    local focus = head.Position + Vector3.new(0, 0.5, 0)
    local rot = CFrame.fromEulerAnglesYXZ(tpPitch or 0, tpYaw or 0, 0)
    Camera.CFrame = CFrame.new(focus) * rot * CFrame.new(0, 0, dist)
end

UserInputService.InputChanged:Connect(function(input)
    pcall(function()
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if not GetFlag("thirdperson_toggle") or GetFlag("freecam_toggle") then return end
        local sens = 0.0035
        tpYaw = (tpYaw or 0) - input.Delta.X * sens
        tpPitch = math.clamp((tpPitch or 0) - input.Delta.Y * sens, -1.2, 1.2)
    end)
end)

local function UpdateFreecam(dt)
    if not GetFlag("freecam_toggle") or not freecamCam then return end
    local speed = GetFlag("freecam_speed", 131)
    local move = Vector3.new(0, 0, 0)
    local look = freecamCam.LookVector
    local right = freecamCam.RightVector
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + look end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - look end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + right end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - right end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end
    if move.Magnitude > 0 then
        freecamCam = freecamCam + move.Unit * speed * dt
    end
    Camera.CameraType = Enum.CameraType.Scriptable
    Camera.CFrame = freecamCam
end

-- ============================================================
-- WORLD MODULATION (UD)
-- ============================================================
local originalAmbient = Lighting.Ambient
local originalFogEnd = Lighting.FogEnd

local function UpdateWorldModulation()
    if GetFlag("ambient_toggle") then
        local col = GetFlag("ambient_colour")
        if Lighting.Ambient ~= col then Lighting.Ambient = col end
        if Lighting.OutdoorAmbient ~= col then Lighting.OutdoorAmbient = col end
    else
        if Lighting.Ambient ~= originalAmbient then Lighting.Ambient = originalAmbient end
        if Lighting.OutdoorAmbient ~= originalAmbient then Lighting.OutdoorAmbient = originalAmbient end
    end
    if GetFlag("noFog_toggle") then
        if Lighting.FogEnd ~= 999999 then Lighting.FogEnd = 999999 end
        if Lighting.FogStart ~= 0 then Lighting.FogStart = 0 end
    elseif Lighting.FogEnd ~= originalFogEnd then
        Lighting.FogEnd = originalFogEnd
    end
    if GetFlag("timeOfDay_toggle") then
        Lighting.ClockTime = GetFlag("timeOfDay")
    end
    if GetFlag("removeGrass_toggle") then
        pcall(function() setfflag("FRMMinGrassDistance","-1"); setfflag("FRMMaxGrassDistance","-1") end)
    end
end

-- ============================================================
-- SPEEDHACK + FLY
-- ============================================================
local function SpeedHack()
    if not GetFlag("speedHack_toggle") then return end
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then return end
    local speed = GetFlag("speedHack_amount")
    local moveDir = humanoid.MoveDirection
    local vel = root.Velocity
    root.Velocity = Vector3.new(moveDir.X * speed, vel.Y, moveDir.Z * speed)
end

local function Fly()
    if not GetFlag("fly_toggle") then return end
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local speed = GetFlag("fly_speed")
    local dir = Vector3.new(0,0,0)
    local cf = root.CFrame
    local _, ry, _ = cf:ToOrientation()
    local look = CFrame.fromOrientation(0, ry, 0).LookVector
    local right = CFrame.fromOrientation(0, ry, 0).RightVector
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + look end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - look end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + right end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - right end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
    if dir.Magnitude > 0 then
        root.Velocity = dir.Unit * Vector3.new(speed, speed, speed)
        root.Anchored = false
    else
        root.Anchored = true
    end
end

-- ============================================================
-- STAFF DETECTOR
-- ============================================================
local staffList = {}
local GROUP_ID = 1154360
local MIN_STAFF_RANK = 6

local STAFF_ROLES = {
    [16681869] = "Founder", [47983795] = "Co-Founder",
    [25548179] = "Lead Developer", [363101315] = "Lead Developer",
    [584370127] = "Game Moderator", [4243907215] = "Game Moderator",
}

local function CheckStaff(player)
    if not player or player == LocalPlayer then return nil end
    local uid = tonumber(player.UserId)
    if uid and STAFF_ROLES[uid] then return STAFF_ROLES[uid] end
    local success, rank = pcall(function() return player:GetRankInGroup(GROUP_ID) end)
    if success and rank >= MIN_STAFF_RANK then
        local ok, role = pcall(function() return player:GetRoleInGroup(GROUP_ID) end)
        return ok and role or "STAFF"
    end
    return nil
end

local function UpdateStaffList()
    staffList = {}
    for _, player in Players:GetPlayers() do
        if player ~= LocalPlayer then
            local role = CheckStaff(player)
            if role then
                staffList[player.UserId] = { player = player, role = role, name = player.DisplayName or player.Name }
            end
        end
    end
end

-- ============================================================
-- ARMOUR LIST
-- ============================================================
local function GetPlayerArmour(player)
    local character = player.Character
    if not character then return "none" end
    local inv = character:FindFirstChild("InventoryController")
    if not inv then return "none" end
    local armour = inv:FindFirstChild("ArmourModel") or inv:FindFirstChild("Armor")
    if armour then
        local parts = {}
        for _, part in armour:GetChildren() do
            if part:IsA("BasePart") or part:IsA("MeshPart") then
                table.insert(parts, part.Name)
            end
        end
        return #parts > 0 and table.concat(parts, ", ") or "none"
    end
    return "none"
end

-- ============================================================
-- NPC SCAN
-- ============================================================
local npcCacheList, npcCacheAt = nil, 0

local function GetNPCs()
    local now = os.clock()
    if npcCacheList and now - npcCacheAt < 0.5 then
        return npcCacheList
    end
    local npcs = {}
    for _, folder in ipairs({ Workspace:FindFirstChild("Npcs"), Workspace:FindFirstChild("Animals") }) do
        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                if model:FindFirstChildOfClass("Humanoid") then
                    table.insert(npcs, model)
                end
            end
        end
    end
    npcCacheList = npcs
    npcCacheAt = now
    return npcs
end

local function IsTeammate(player)
    local ok, team = pcall(function() return player.Team end)
    local myTeam = LocalPlayer.Team
    return ok and team ~= nil and myTeam ~= nil and team == myTeam
end

-- ============================================================
-- TARGET SELECTION (camera aim)
-- ============================================================
local function GetClosestTarget(fovOverride)
    local mousePos = UserInputService:GetMouseLocation()
    local fov = fovOverride or GetFlag("silentAim_fovSize", 205)
    if not fovOverride and GetFlag("silentAim_dynamicFov") then
        fov = fov / math.max(Camera.FieldOfView / 70, 0.01)
    end
    local best, bestDist = nil, fov
    local hitpart = GetFlag("silentAim_hitpart", "head")

    for _, player in Players:GetPlayers() do
        if player ~= LocalPlayer then
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local skip = false
                if GetFlag("silentAim_teamCheck") and IsTeammate(player) then
                    skip = true
                end
                if not skip then
                    local part
                    if hitpart == "torso" then
                        part = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
                    elseif hitpart == "closest" then
                        part = char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso")
                    else
                        part = char:FindFirstChild("Head")
                    end
                    if part then
                        local spos, vis = WorldToScreen(part.Position)
                        if vis then
                            local d = (spos - mousePos).Magnitude
                            if d < bestDist then bestDist = d; best = { part = part, player = player } end
                        end
                    end
                end
            end
        end
    end

    if not best and GetFlag("silentAim_targetNpcs") then
        for _, npc in GetNPCs() do
            if npc.Parent then
                local root = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
                if root then
                    local spos, vis = WorldToScreen(root.Position)
                    if vis then
                        local d = (spos - mousePos).Magnitude
                        if d < bestDist then bestDist = d; best = { part = root, npc = npc } end
                    end
                end
            end
        end
    end
    return best
end

-- ============================================================
-- PER-FRAME RENDER
-- ============================================================
local frameCount = 0

RunService.PreRender:Connect(function()
    local ok, err = pcall(function()
    Camera = Workspace.CurrentCamera
    frameCount = frameCount + 1

    -- ===== PLAYER ESP =====
    local function renderPlayer(player)
        if player == LocalPlayer then return end
            if GetFlag("playerEsp_teamCheck") and IsTeammate(player) then
                return
            end
            local character = player.Character
            if not character then return end
            local root = GetCharacterRoot(character)
            if not root then return end
            local pos, onScreen, _ = WorldToScreen(root.Position)
            if not onScreen then return end

            local health, maxHealth = GetHealth(character)
            local weapon = GetWeaponName(character)
            local screenDist = (Camera.CFrame.Position - root.Position).Magnitude
            local espColor = GetFlag("playerEsp_boxColour")

            -- Get or create ESP objects
            local objs = playerESPObjects[player]
            if not objs then
                objs = CreatePlayerESPObjects()
                playerESPObjects[player] = objs
            end

            -- Box ESP
            if GetFlag("playerEsp_box") then
                local topW2V, topVis = WorldToScreen(root.Position + Vector3.new(0, 2.5, 0))
                local botW2V, botVis = WorldToScreen(root.Position - Vector3.new(0, 2.5, 0))
                if topVis and botVis then
                    local boxW = math.abs(topW2V.Y - botW2V.Y) * 0.4
                    objs.box.Position = Vector2.new(topW2V.X - boxW, topW2V.Y)
                    objs.box.Size = Vector2.new(boxW * 2, botW2V.Y - topW2V.Y)
                    objs.box.Color = espColor
                    objs.box.Thickness = 1
                    objs.box.Filled = false
                    objs.box.Transparency = 0.2
                    objs.box.Visible = true
                end
            else objs.box.Visible = false end

            -- Corner Box
            if GetFlag("playerEsp_cornerBox") then
                local topW2V, topVis = WorldToScreen(root.Position + Vector3.new(0, 2.5, 0))
                local botW2V, botVis = WorldToScreen(root.Position - Vector3.new(0, 2.5, 0))
                if topVis and botVis then
                    local boxW = math.abs(topW2V.Y - botW2V.Y) * 0.4
                    local tl = Vector2.new(topW2V.X - boxW, topW2V.Y)
                    local tr = Vector2.new(topW2V.X + boxW, topW2V.Y)
                    local bl = Vector2.new(botW2V.X - boxW, botW2V.Y)
                    local br = Vector2.new(botW2V.X + boxW, botW2V.Y)
                    local sz = boxW * 0.3
                    local th = 1; local t = 0.2
                    -- Top-left
                    objs.cornerTL.From = tl; objs.cornerTL.To = Vector2.new(tl.X + sz, tl.Y); objs.cornerTL.Visible = true; objs.cornerTL.Color = espColor; objs.cornerTL.Thickness = th; objs.cornerTL.Transparency = t
                    objs.cornerTLa.From = tl; objs.cornerTLa.To = Vector2.new(tl.X, tl.Y + sz); objs.cornerTLa.Visible = true; objs.cornerTLa.Color = espColor; objs.cornerTLa.Thickness = th; objs.cornerTLa.Transparency = t
                    -- Top-right
                    objs.cornerTR.From = tr; objs.cornerTR.To = Vector2.new(tr.X - sz, tr.Y); objs.cornerTR.Visible = true; objs.cornerTR.Color = espColor; objs.cornerTR.Thickness = th; objs.cornerTR.Transparency = t
                    objs.cornerTRa.From = tr; objs.cornerTRa.To = Vector2.new(tr.X, tr.Y + sz); objs.cornerTRa.Visible = true; objs.cornerTRa.Color = espColor; objs.cornerTRa.Thickness = th; objs.cornerTRa.Transparency = t
                    -- Bottom-left
                    objs.cornerBL.From = bl; objs.cornerBL.To = Vector2.new(bl.X + sz, bl.Y); objs.cornerBL.Visible = true; objs.cornerBL.Color = espColor; objs.cornerBL.Thickness = th; objs.cornerBL.Transparency = t
                    objs.cornerBLa.From = bl; objs.cornerBLa.To = Vector2.new(bl.X, bl.Y - sz); objs.cornerBLa.Visible = true; objs.cornerBLa.Color = espColor; objs.cornerBLa.Thickness = th; objs.cornerBLa.Transparency = t
                    -- Bottom-right
                    objs.cornerBR.From = br; objs.cornerBR.To = Vector2.new(br.X - sz, br.Y); objs.cornerBR.Visible = true; objs.cornerBR.Color = espColor; objs.cornerBR.Thickness = th; objs.cornerBR.Transparency = t
                    objs.cornerBRa.From = br; objs.cornerBRa.To = Vector2.new(br.X, br.Y - sz); objs.cornerBRa.Visible = true; objs.cornerBRa.Color = espColor; objs.cornerBRa.Thickness = th; objs.cornerBRa.Transparency = t
                end
            else
                objs.cornerTL.Visible = false; objs.cornerTLa.Visible = false
                objs.cornerTR.Visible = false; objs.cornerTRa.Visible = false
                objs.cornerBL.Visible = false; objs.cornerBLa.Visible = false
                objs.cornerBR.Visible = false; objs.cornerBRa.Visible = false
            end

            -- Skeleton
            if GetFlag("playerEsp_skeleton") then
                for _, bonePair in { {"Head","UpperTorso"},{"UpperTorso","LeftUpperArm"},{"UpperTorso","RightUpperArm"},{"LeftUpperArm","LeftHand"},{"RightUpperArm","RightHand"},{"UpperTorso","LeftUpperLeg"},{"UpperTorso","RightUpperLeg"} } do
                    local p1 = character:FindFirstChild(bonePair[1])
                    local p2 = character:FindFirstChild(bonePair[2])
                    if p1 and p2 then
                        local s1, v1 = WorldToScreen(p1.Position)
                        local s2, v2 = WorldToScreen(p2.Position)
                        if v1 and v2 then
                            local line = objs.skeletonLines[bonePair[1].."_"..bonePair[2]]
                            if not line then line = Drawing.new("Line"); objs.skeletonLines[bonePair[1].."_"..bonePair[2]] = line end
                            line.From = s1; line.To = s2
                            line.Color = GetFlag("playerEsp_skeletonColour") or espColor; line.Thickness = 1.5
                            line.Transparency = 0.2; line.Visible = true
                        end
                    end
                end
            else
                for _, line in objs.skeletonLines do line.Visible = false end
            end

            -- Name
            if GetFlag("playerEsp_name") then
                objs.nameText.Text = EffectiveName(player)
                objs.nameText.Color = GetFlag("playerEsp_nameColour")
                objs.nameText.Size = 14
                objs.nameText.Center = true
                objs.nameText.Outline = true
                objs.nameText.Position = Vector2.new(pos.X, pos.Y - 40)
                objs.nameText.Transparency = 0.2
                objs.nameText.Visible = true
            else objs.nameText.Visible = false end

            -- Distance
            if GetFlag("playerEsp_distance") then
                objs.distText.Text = string.format("[%d studs]", screenDist)
                objs.distText.Color = GetFlag("playerEsp_distanceColour")
                objs.distText.Size = 12; objs.distText.Center = true; objs.distText.Outline = true
                objs.distText.Position = Vector2.new(pos.X, pos.Y + 40)
                objs.distText.Transparency = 0.2; objs.distText.Visible = true
            else objs.distText.Visible = false end

            -- Weapon
            if GetFlag("playerEsp_weapon") then
                objs.weaponText.Text = string.format("[%s]", weapon)
                objs.weaponText.Color = GetFlag("playerEsp_weaponColour")
                objs.weaponText.Size = 12; objs.weaponText.Center = true; objs.weaponText.Outline = true
                objs.weaponText.Position = Vector2.new(pos.X, pos.Y + 55)
                objs.weaponText.Transparency = 0.2; objs.weaponText.Visible = true
            else objs.weaponText.Visible = false end

            -- Healthbar
            if GetFlag("playerEsp_healthbar") then
                local barPos, barVis = WorldToScreen(root.Position + Vector3.new(0, 2.8, 0))
                if barVis then
                    local barW = 40; local barH = 3
                    local healthPct = _mathclamp(health / maxHealth, 0, 1)
                    objs.healthBarBg.Position = Vector2.new(barPos.X - barW/2, barPos.Y)
                    objs.healthBarBg.Size = Vector2.new(barW, barH)
                    objs.healthBarBg.Color = Color3.fromRGB(0,0,0); objs.healthBarBg.Filled = true
                    objs.healthBarBg.Transparency = 0.3; objs.healthBarBg.Visible = true
                    objs.healthBar.Position = Vector2.new(barPos.X - barW/2, barPos.Y)
                    objs.healthBar.Size = Vector2.new(barW * healthPct, barH)
                    objs.healthBar.Color = Color3.fromRGB(255*(1-healthPct), 255*healthPct, 0)
                    objs.healthBar.Filled = true; objs.healthBar.Transparency = 0.2; objs.healthBar.Visible = true
                end
            else objs.healthBarBg.Visible = false; objs.healthBar.Visible = false end

            -- Tracers
            if GetFlag("playerEsp_tracers") then
                objs.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                objs.tracer.To = pos
                objs.tracer.Color = espColor
                objs.tracer.Thickness = 1
                objs.tracer.Transparency = 0.4
                objs.tracer.Visible = true
            else
                objs.tracer.Visible = false
            end
        end

    if GetFlag("playerEsp_toggle") then
        for _, player in Players:GetPlayers() do
            renderPlayer(player)
        end
    else
        -- Hide all player ESP objects
        for _, objs in playerESPObjects do
            objs.box.Visible = false; objs.nameText.Visible = false
            objs.distText.Visible = false; objs.weaponText.Visible = false
            objs.healthBar.Visible = false; objs.healthBarBg.Visible = false
            objs.cornerTL.Visible = false; objs.cornerTLa.Visible = false
            objs.cornerTR.Visible = false; objs.cornerTRa.Visible = false
            objs.cornerBL.Visible = false; objs.cornerBLa.Visible = false
            objs.cornerBR.Visible = false; objs.cornerBRa.Visible = false
            objs.tracer.Visible = false
            for _, line in objs.skeletonLines do line.Visible = false end
        end
    end

    -- ===== NPC ESP =====
    local npcSeen = {}
    if GetFlag("npcEsp_toggle") then
        local maxDist = GetFlag("npcEsp_maxDistance")
        for _, npc in GetNPCs() do
            local settings = npc.Parent and NPC_SETTINGS[npc.Name]
            if settings then
                local flagKey = settings.flag or settings.name
                local root = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
                local pos, onScreen
                if root then pos, onScreen = WorldToScreen(root.Position) end
                local dist = root and (Camera.CFrame.Position - root.Position).Magnitude or 1e9
                if GetFlag("npcEsp_" .. flagKey) and onScreen and dist <= maxDist then
                    npcSeen[npc] = true
                    local npcColour = GetFlag("npcEsp_" .. flagKey .. "Colour") or settings.colour
                    local o = npcESPObjects[npc]
                    if not o then o = CreateNPCObjects(); npcESPObjects[npc] = o end
                    local humanoid = npc:FindFirstChildOfClass("Humanoid")
                    local health = humanoid and humanoid.Health or 0
                    local maxHealth = humanoid and humanoid.MaxHealth or 100

                    if GetFlag("npcEsp_box") then
                        o.box.Size = Vector2.new(3, 5)
                        o.box.Position = Vector2.new(pos.X - 1.5, pos.Y - 2.5)
                        o.box.Color = npcColour; o.box.Thickness = 1; o.box.Filled = false
                        o.box.Transparency = 0.2; o.box.Visible = true
                    else o.box.Visible = false end

                    if GetFlag("npcEsp_name") then
                        o.nameText.Text = settings.name:upper(); o.nameText.Color = npcColour
                        o.nameText.Size = 13; o.nameText.Center = true; o.nameText.Outline = true
                        o.nameText.Position = Vector2.new(pos.X, pos.Y - 30)
                        o.nameText.Transparency = 0.2; o.nameText.Visible = true
                    else o.nameText.Visible = false end

                    if GetFlag("npcEsp_distance") then
                        o.distText.Text = string.format("[%d studs]", dist); o.distText.Color = npcColour
                        o.distText.Size = 11; o.distText.Center = true; o.distText.Outline = true
                        o.distText.Position = Vector2.new(pos.X, pos.Y + 25)
                        o.distText.Transparency = 0.2; o.distText.Visible = true
                    else o.distText.Visible = false end

                    if GetFlag("npcEsp_healthbar") then
                        local barW, barH = 30, 2
                        local healthPct = _mathclamp(health / maxHealth, 0, 1)
                        o.healthBarBg.Position = Vector2.new(pos.X - barW/2, pos.Y + 30)
                        o.healthBarBg.Size = Vector2.new(barW, barH)
                        o.healthBarBg.Color = Color3.fromRGB(0,0,0); o.healthBarBg.Filled = true
                        o.healthBarBg.Transparency = 0.3; o.healthBarBg.Visible = true
                        o.healthBar.Position = Vector2.new(pos.X - barW/2, pos.Y + 30)
                        o.healthBar.Size = Vector2.new(barW * healthPct, barH)
                        o.healthBar.Color = Color3.fromRGB(255*(1-healthPct), 255*healthPct, 0)
                        o.healthBar.Filled = true; o.healthBar.Transparency = 0.2; o.healthBar.Visible = true
                    else o.healthBar.Visible = false; o.healthBarBg.Visible = false end
                end
            end
        end
    end
    for npc, o in npcESPObjects do
        if not npcSeen[npc] or not npc.Parent then
            o.box.Visible = false; o.nameText.Visible = false; o.distText.Visible = false
            o.healthBar.Visible = false; o.healthBarBg.Visible = false
            if not npc.Parent then
                o.box:Remove(); o.nameText:Remove(); o.distText:Remove()
                o.healthBar:Remove(); o.healthBarBg:Remove()
                npcESPObjects[npc] = nil
            end
        end
    end

    -- ===== ENTITY ESP =====
    local entSeen = {}
    if GetFlag("entityEsp_toggle") then
        local maxDist = GetFlag("entityEsp_maxDistance")
        local function RenderEntity(entity, settings)
            local flagKey = settings.flag or settings.name
            if not GetFlag("entityEsp_" .. flagKey) then return end
            local pos, onScreen, worldPos
            if entity:IsA("Model") then
                worldPos = entity:GetPivot().Position
                pos, onScreen = WorldToScreen(worldPos)
            elseif entity:IsA("BasePart") then
                worldPos = entity.Position
                pos, onScreen = WorldToScreen(worldPos)
            end
            if not onScreen then return end
            local dist = (Camera.CFrame.Position - worldPos).Magnitude
            if dist > maxDist then return end
            entSeen[entity] = true
            local colour = GetFlag("entityEsp_" .. flagKey .. "Colour") or settings.colour
            local o = entityESPObjects[entity]
            if not o then o = CreateEntityObjects(); entityESPObjects[entity] = o end

            if GetFlag("entityEsp_box") then
                o.box.Size = Vector2.new(3, 3)
                o.box.Position = Vector2.new(pos.X - 1.5, pos.Y - 1.5)
                o.box.Color = colour; o.box.Thickness = 1; o.box.Filled = false
                o.box.Transparency = 0.2; o.box.Visible = true
            else o.box.Visible = false end

            if GetFlag("entityEsp_name") then
                o.nameText.Text = settings.name:upper(); o.nameText.Color = colour
                o.nameText.Size = 12; o.nameText.Center = true; o.nameText.Outline = true
                o.nameText.Position = Vector2.new(pos.X, pos.Y - 20)
                o.nameText.Transparency = 0.2; o.nameText.Visible = true
            else o.nameText.Visible = false end

            if GetFlag("entityEsp_distance") then
                o.distText.Text = string.format("[%d]", dist); o.distText.Color = colour
                o.distText.Size = 10; o.distText.Center = true; o.distText.Outline = true
                o.distText.Position = Vector2.new(pos.X, pos.Y + 15)
                o.distText.Transparency = 0.2; o.distText.Visible = true
            else o.distText.Visible = false end
        end
        local function scanFolder(folder, fallbackKey)
            if not folder then return end
            for _, child in ipairs(folder:GetChildren()) do
                local s = ENTITY_SETTINGS[child.Name] or (fallbackKey and ENTITY_SETTINGS[fallbackKey])
                if s then RenderEntity(child, s) end
            end
        end
        scanFolder(NodesFolder, "node")
        scanFolder(LootFolder, "loot")
        scanFolder(WorldItemsFolder, "Item")
        scanFolder(AirdropsFolder, "Airdrop")
        scanFolder(MinicoptersFolder, "Minicopter")
        scanFolder(BoatsFolder, "Boat")
        scanFolder(PickupsFolder, "Pickup")
        scanFolder(DeployablesFolder, "deployable")
    end
    for entity, o in entityESPObjects do
        if not entSeen[entity] or not entity.Parent then
            o.box.Visible = false; o.nameText.Visible = false; o.distText.Visible = false
            if not entity.Parent then
                o.box:Remove(); o.nameText:Remove(); o.distText:Remove()
                entityESPObjects[entity] = nil
            end
        end
    end
    end)
end)

local gunCache = {}

local function GetGunBallistics()
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    local name = tool and tool.Name or nil
    if name and gunCache[name] then
        return gunCache[name][1], gunCache[name][2]
    end
    local speed, gravity = 900, 196.2
    if name then
        pcall(function()
            local fust = ReplicatedStorage:FindFirstChild("Fust")
            local mod = fust and fust:FindFirstChild("Items")
            if not mod then return end
            local items = require(mod)
            if type(items) ~= "table" then return end
            local entry = items[name]
            if type(entry) ~= "table" then
                for _, v in pairs(items) do
                    if type(v) == "table" and (v.Name == name or v.id == name or v.Id == name) then
                        entry = v
                        break
                    end
                end
            end
            if type(entry) ~= "table" then return end
            local sVal = entry.speed or entry.Speed or entry.bulletSpeed or entry.BulletSpeed or entry.velocity or entry.Velocity
            local gVal = entry.gravity or entry.Gravity or entry.drop or entry.Drop or entry.GravityMult
            if type(sVal) == "number" and sVal > 0 then speed = sVal end
            if type(gVal) == "number" and gVal > 0 then gravity = gVal end
        end)
        gunCache[name] = { speed, gravity }
    end
    return speed, gravity
end

local function BallisticAim(camPos, part)
    local speed, gravity = GetGunBallistics()
    local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new()
    local target = part.Position
    local tof = (target - camPos).Magnitude / math.max(speed, 1)
    local aim = target
    for _ = 1, 4 do
        aim = target + vel * tof + Vector3.new(0, 0.5 * gravity * tof * tof, 0)
        tof = (aim - camPos).Magnitude / math.max(speed, 1)
    end
    return aim
end

local heldInputs = {}

local EMOTES = {
    ["Zombie"] = 128071469092981,
    ["Take the L"] = 122624487269599,
    ["Floppy Fly"] = 111689026005752,
}

local emoteTracks = {}

local function PlayEmote(name)
    local id = EMOTES[name]
    if not id then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local animate = char:FindFirstChild("Animate")
    local binder = animate and animate:FindFirstChild("PlayEmote")
    if binder and binder:IsA("BindableFunction") then
        pcall(function() binder:Invoke(tostring(id)) end)
        pcall(function() binder:Invoke(name) end)
    end

    local animator = hum:FindFirstChildOfClass("Animator") or (function()
        local a = Instance.new("Animator")
        a.Parent = hum
        return a
    end)()
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. tostring(id)
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if ok and track then
        for _, t in pairs(emoteTracks) do
            if t and t.IsPlaying then pcall(function() t:Stop() end) end
        end
        emoteTracks = {}
        table.insert(emoteTracks, track)
        pcall(function() track:Play() end)
    end
end

-- silent aim / force hit / manipulation via workspace.Raycast hook
local raycastHooked = false
local function EnsureRaycastHook()
    if raycastHooked or not hookfunction then return end
    pcall(function()
        local old = workspace.Raycast
        local new = newcclosure(function(self, origin, direction, params)
            if self ~= workspace then
                return old(self, origin, direction, params)
            end
            if not GetFlag("silentAim_toggle") then
                return old(self, origin, direction, params)
            end
            if genv.pulsarMenuOpen or not (heldInputs and heldInputs["MouseButton1"]) then
                return old(self, origin, direction, params)
            end
            local target = GetClosestTarget()
            if not target or not target.part then
                return old(self, origin, direction, params)
            end
            local roll = math.random(0, 99)
            if not GetFlag("silentAim_instantHit") and roll >= GetFlag("silentAim_hitchance", 100) then
                return old(self, origin, direction, params)
            end
            local pos = target.part.Position
            local castOrigin = origin
            if GetFlag("silentAim_manipulation") then
                local delta = pos - origin
                if delta.Magnitude > 0.01 then
                    castOrigin = pos - delta.Unit * math.clamp(GetFlag("silentAim_manipulationDistance", 8), 1, 8)
                end
            end
            local filter = RaycastParams.new()
            filter.FilterType = Enum.RaycastFilterType.Include
            filter.FilterDescendantsInstances = { target.character or target.part.Parent }
            local result = old(self, castOrigin, pos - castOrigin, filter)
            if result then return result end
            return old(self, origin, direction, params)
        end)
        hookfunction(old, new)
        raycastHooked = true
    end)
end

-- client-only desync (CameraModule sees a rotated root)
local desyncState = nil
local function ApplyDesync()
    if desyncState then return end
    pcall(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root or not getrawmetatable then return end
        local mt = getrawmetatable(root)
        local oldIndex = mt.__index
        setreadonly(mt, false)
        mt.__index = newcclosure(function(self, key)
            local value = oldIndex(self, key)
            if key == "CFrame" and not checkcaller() then
                local ok, name = pcall(function()
                    local sc = getcallingscript and getcallingscript()
                    return sc and sc.Name
                end)
                if ok and name == "CameraModule" then
                    return value * CFrame.Angles(0, math.rad(GetFlag("desync_angle", 90)), 0)
                end
            end
            return value
        end)
        setreadonly(mt, true)
        desyncState = { mt = mt, oldIndex = oldIndex }
    end)
end

local function RemoveDesync()
    if not desyncState then return end
    pcall(function()
        setreadonly(desyncState.mt, false)
        rawset(desyncState.mt, "__index", desyncState.oldIndex)
        setreadonly(desyncState.mt, true)
    end)
    desyncState = nil
end

OnFlag("desync_toggle", function(on)
    if on then ApplyDesync() else RemoveDesync() end
end)

LocalPlayer.CharacterAdded:Connect(function()
    if GetFlag("desync_toggle") then
        desyncState = nil
        task.wait(1)
        ApplyDesync()
    end
end)

-- ============================================================
-- GAMEPLAY LOOPS
-- ============================================================
local aimCooldown = 0
local aimFracX, aimFracY = 0, 0

UserInputService.InputBegan:Connect(function(input)
    pcall(function()
        local n = input.UserInputType.Name
        if n and n ~= "None" then heldInputs[n] = true end
        if input.KeyCode and input.KeyCode.Name ~= "Unknown" then heldInputs[input.KeyCode.Name] = true end
    end)
end)

UserInputService.InputEnded:Connect(function(input)
    pcall(function()
        local n = input.UserInputType.Name
        if n and n ~= "None" then heldInputs[n] = false end
        if input.KeyCode and input.KeyCode.Name ~= "Unknown" then heldInputs[input.KeyCode.Name] = false end
    end)
end)
EnsureRaycastHook()

RunService.RenderStepped:Connect(function(dt)
    local ok, err = pcall(function()
    Camera = Workspace.CurrentCamera
    frameCount = frameCount + 1
    UpdateLocalChams()
    UpdatePlayerChams()

    if GetFlag("thirdperson_toggle") then
        UpdateThirdperson()
    elseif Camera.CameraType == Enum.CameraType.Scriptable then
        Camera.CameraType = Enum.CameraType.Custom
    end

    if GetFlag("aimbot_toggle") and not genv.pulsarMenuOpen then
        local aimKey = Keybinds.aimbot or "MouseButton2"
        if heldInputs[aimKey] then
            local target = GetClosestTarget(GetFlag("aimbot_fov", 250))
            if target and target.part then
                local camPos = Camera.CFrame.Position
                local aimPoint = target.part.Position
                if GetFlag("aimbot_prediction", true) then
                    aimPoint = BallisticAim(camPos, target.part)
                end
                local spos, vis = WorldToScreen(aimPoint)
                if vis then
                    local m = UserInputService:GetMouseLocation()
                    local smooth = math.max(GetFlag("aimbot_smoothing", 5), 1)
                    local factor = 1 - math.exp(-dt * (14 / smooth))
                    aimFracX = aimFracX + (spos.X - m.X) * factor
                    aimFracY = aimFracY + (spos.Y - m.Y) * factor
                    local mx = math.floor(aimFracX)
                    local my = math.floor(aimFracY)
                    aimFracX = aimFracX - mx
                    aimFracY = aimFracY - my
                    local moved = false
                    if mx ~= 0 or my ~= 0 then
                        local rel = mousemoverel or mouse_move_rel
                        if rel then moved = pcall(rel, mx, my) end
                        if not moved then
                            local abs = mousemoveabs or mouse_move_abs
                            if abs then moved = pcall(abs, m.X + mx, m.Y + my) end
                        end
                    end
                    if not moved then
                        local desired = CFrame.lookAt(camPos, aimPoint)
                        Camera.CFrame = Camera.CFrame:Lerp(desired, factor)
                    end
                end
            end
        end
    end
    if GetFlag("staffDetector_toggle") and frameCount % 300 == 0 then UpdateStaffList() end
    end)
end)

-- ============================================================
-- HITMARKER DETECTION (health based)
-- ============================================================
local targetHealthCache = setmetatable({}, { __mode = "k" })
local lastFireAt = -math.huge

UserInputService.InputBegan:Connect(function(input, gpe)
    pcall(function()
        if input.UserInputType == Enum.UserInputType.MouseButton1 and not gpe and not genv.pulsarMenuOpen then
            lastFireAt = os.clock()
        end
    end)
end)

local hitAccum = 0
RunService.Heartbeat:Connect(function(dt)
    pcall(function()
        hitAccum = hitAccum + dt
        if hitAccum < 0.05 then return end
        hitAccum = 0
        if not GetFlag("hitmarkers_toggle") then return end

        local seen = {}
        local function check(char)
            if not char or char == LocalPlayer.Character then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            seen[char] = true
            local prev = targetHealthCache[char]
            local cur = hum.Health
            if prev and cur < prev - 0.5 and (os.clock() - lastFireAt) <= 0.8 then
                local part = char:FindFirstChild("Head") or char.PrimaryPart
                if part then
                    local _, vis = WorldToScreen(part.Position)
                    if vis then DrawHitmarker() end
                end
            end
            targetHealthCache[char] = cur
        end

        for _, p in Players:GetPlayers() do
            if p ~= LocalPlayer then check(p.Character) end
        end
        for _, n in GetNPCs() do
            if n.Parent then check(n) end
        end
        for c in targetHealthCache do
            if not seen[c] then targetHealthCache[c] = nil end
        end
    end)
end)

-- ============================================================
-- PLAYER CLEANUP
-- ============================================================
Players.PlayerRemoving:Connect(function(player)
    pcall(function()
    local objs = playerESPObjects[player]
    if objs then
        objs.box:Remove(); objs.nameText:Remove(); objs.distText:Remove()
        objs.weaponText:Remove(); objs.healthBar:Remove(); objs.healthBarBg:Remove()
        objs.cornerTL:Remove(); objs.cornerTLa:Remove(); objs.cornerTR:Remove(); objs.cornerTRa:Remove()
        objs.cornerBL:Remove(); objs.cornerBLa:Remove(); objs.cornerBR:Remove(); objs.cornerBRa:Remove()
        objs.tracer:Remove()
        for _, line in objs.skeletonLines do line:Remove() end
        playerESPObjects[player] = nil
    end
    end)
end)

-- ============================================================
-- PULSAR.ONE MENU  (Drawing only - no ScreenGui / Frames)
-- ============================================================
local KEYBIND_FILE = "PulsarOne_Keybinds.txt"
local Keybinds = {
    menu = "RightShift",
    players = "",
    aimbot = "MouseButton2",
}

local KeybindActions = {
    players = "playerEsp_toggle",
}

local function keyCodeFromName(name)
    if not name or name == "" then return nil end
    local ok, code = pcall(function() return Enum.KeyCode[name] end)
    return ok and code or nil
end

local function saveKeybinds()
    local lines = {}
    for key, value in pairs(Keybinds) do
        if value and value ~= "" then
            lines[#lines + 1] = string.format("%s=%s", key, value)
        end
    end
    table.sort(lines)
    if writefile then pcall(writefile, KEYBIND_FILE, table.concat(lines, "\n")) end
end

local function loadKeybinds()
    if not readfile then return end
    if isfile and not isfile(KEYBIND_FILE) then return end
    local ok, text = pcall(readfile, KEYBIND_FILE)
    if not ok or type(text) ~= "string" then return end
    for line in string.gmatch(text, "[^\r\n]+") do
        local key, value = string.match(line, "^(%w+)=(%w+)$")
        if key and value then Keybinds[key] = value end
    end
    Keybinds.menu = Keybinds.menu or "RightShift"
end

loadKeybinds()

local UI = {
    open = true,
    tab = "visuals",
    objs = {},
    base = {},
    groups = {},
    clicks = {},
    offsets = {},
    listening = nil,
    typing = nil,
    drag = nil,
}

local C = {
    bg = Color3.fromRGB(16, 20, 30),
    panel = Color3.fromRGB(22, 27, 38),
    line = Color3.fromRGB(8, 10, 16),
    text = Color3.fromRGB(205, 212, 228),
    dim = Color3.fromRGB(130, 138, 155),
    accent = Color3.fromRGB(56, 124, 255),
    white = Color3.fromRGB(255, 255, 255),
}

local FONT = Drawing.Fonts.UI
local V2 = Vector2.new
local W, H = 560, 585
local origin = V2(math.floor(Camera.ViewportSize.X / 2 - W / 2), math.floor(Camera.ViewportSize.Y / 2 - H / 2))

local function add(class, props, tab)
    local o = Drawing.new(class)
    for k, v in props do o[k] = v end
    table.insert(UI.objs, o)
    if tab then
        UI.groups[tab] = UI.groups[tab] or {}
        table.insert(UI.groups[tab], o)
    else
        table.insert(UI.base, o)
    end
    return o
end

local function click(obj, fn, tab)
    table.insert(UI.clicks, { obj = obj, fn = fn, tab = tab })
end

local function clickSize(obj)
    local size = obj.Size
    local ok, t = pcall(function() return typeof(size) end)
    if ok and t == "Vector2" then return size end
    local bounds = obj.TextBounds
    local ok2, t2 = pcall(function() return typeof(bounds) end)
    if ok2 and t2 == "Vector2" then return bounds end
    return Vector2.new(1, 1)
end

local function within(p, pos, size)
    local o = p - pos
    return o.X >= 0 and o.Y >= 0 and o.X < size.X and o.Y < size.Y
end

-- base window
add("Square", { Visible = true, Filled = true, Color = C.line, Position = origin - V2(1, 1), Size = V2(W + 2, H + 2), ZIndex = 100 })
add("Square", { Visible = true, Filled = true, Color = C.bg, Position = origin, Size = V2(W, H), ZIndex = 101 })

local title = add("Text", { Visible = true, Text = "Pulsar", Position = origin + V2(12, 6), Size = 15, Font = FONT, Color = C.text, ZIndex = 104 })
add("Text", { Visible = true, Text = ".One", Position = title.Position + V2(title.TextBounds.X, 0), Size = 15, Font = FONT, Color = C.accent, ZIndex = 104 })
add("Text", { Visible = true, Text = "RSHIFT", Position = origin + V2(W - 64, 8), Size = 11, Font = FONT, Color = C.dim, ZIndex = 104 })

local dragBar = add("Square", { Visible = true, Filled = false, Transparency = 1, Color = C.line, Position = origin, Size = V2(W, 24), ZIndex = 102 })
click(dragBar, function() UI.drag = UserInputService:GetMouseLocation() end)

-- tabs
local tabs = { { id = "combat", label = "combat" }, { id = "visuals", label = "visuals" }, { id = "entity", label = "entity" }, { id = "local", label = "local" }, { id = "ui", label = "ui" } }
local tabTexts = {}
for i, t in ipairs(tabs) do
    local x = origin.X + 12 + (i - 1) * 78
    local o = add("Text", { Visible = true, Text = t.label, Position = V2(x, origin.Y + 30), Size = 12, Font = FONT, Color = C.dim, ZIndex = 104 })
    tabTexts[t.id] = o
    local hit = add("Square", { Visible = true, Filled = false, Transparency = 1, Color = C.line, Position = V2(x - 4, origin.Y + 26), Size = V2(70, 18), ZIndex = 102 })
    click(hit, function()
        UI.tab = t.id
        for id, txt in pairs(tabTexts) do
            txt.Color = (id == t.id) and C.white or C.dim
        end
        for tabName, list in pairs(UI.groups) do
            for _, obj in ipairs(list) do
                obj.Visible = UI.open and tabName == UI.tab
            end
        end
    end)
end

local LEFT_X = origin.X + 12
local RIGHT_X = origin.X + 288
local PANEL_W = 268
local TOP_Y = origin.Y + 52
local PANEL_H = H - 64

local function panel(x, tab)
    add("Square", { Visible = true, Filled = false, Thickness = 1, Color = C.line, Position = V2(x, TOP_Y), Size = V2(PANEL_W, PANEL_H), ZIndex = 102 }, tab)
    UI.offsets[tab] = { [x] = TOP_Y + 10 }
end

local function nextY(tab, x)
    return UI.offsets[tab][x]
end

local function bump(tab, x, n)
    UI.offsets[tab][x] = UI.offsets[tab][x] + n
end

local function toggle(tab, x, label, flag, opts)
    opts = opts or {}
    local y = nextY(tab, x)
    local box = add("Square", { Visible = true, Filled = false, Thickness = 1, Color = C.line, Position = V2(x + 10, y), Size = V2(12, 12), ZIndex = 104 }, tab)
    local fill = add("Square", { Visible = true, Filled = true, Color = C.accent, Position = V2(x + 12, y + 2), Size = V2(8, 8), ZIndex = 105 }, tab)
    local txt = add("Text", { Visible = true, Text = label, Position = V2(x + 28, y - 1), Size = 12, Font = FONT, Color = C.text, ZIndex = 104 }, tab)
    fill.Visible = GetFlag(flag) and true or false

    if opts.color then
        local sw = add("Square", { Visible = true, Filled = true, Color = GetFlag(opts.color), Position = V2(x + PANEL_W - 44, y), Size = V2(26, 13), ZIndex = 105 }, tab)
        local outline = add("Square", { Visible = true, Filled = false, Thickness = 1, Color = C.line, Position = V2(x + PANEL_W - 44, y), Size = V2(26, 13), ZIndex = 106 }, tab)
        click(sw, function()
            local palette = {
                Color3.fromRGB(255,255,255), Color3.fromRGB(255,60,60), Color3.fromRGB(255,150,40),
                Color3.fromRGB(255,230,40), Color3.fromRGB(60,220,90), Color3.fromRGB(0,210,220),
                Color3.fromRGB(56,124,255), Color3.fromRGB(150,70,255), Color3.fromRGB(255,40,200),
            }
            local cur = GetFlag(opts.color)
            local idx = 1
            for i, c in ipairs(palette) do if c == cur then idx = i break end end
            idx = (idx % #palette) + 1
            SetFlag(opts.color, palette[idx])
            sw.Color = palette[idx]
        end, tab)
    end

    if opts.bind then
        local badge = add("Text", { Visible = true, Text = "[" .. tostring(Keybinds[opts.bind] or "None") .. "]", Position = V2(x + PANEL_W - 84, y - 1), Size = 11, Font = FONT, Color = C.dim, ZIndex = 105 }, tab)
        click(badge, function()
            UI.listening = opts.bind
            badge.Text = "[...]"
        end, tab)
    end

    OnFlag(flag, function(v) fill.Visible = v and true or false end)
    local hit = add("Square", { Visible = true, Filled = false, Transparency = 1, Color = C.line, Position = V2(x + 6, y - 2), Size = V2(PANEL_W - 12, 18), ZIndex = 103 }, tab)
    click(hit, function() SetFlag(flag, not GetFlag(flag)) end, tab)
    bump(tab, x, 22)
end

local function slider(tab, x, label, flag, minimum, maximum, suffix, decimals)
    local y = nextY(tab, x)
    add("Text", { Visible = true, Text = label, Position = V2(x + 10, y - 1), Size = 11, Font = FONT, Color = C.text, ZIndex = 104 }, tab)
    local value = add("Text", { Visible = true, Text = "", Position = V2(x + PANEL_W - 78, y - 1), Size = 11, Font = FONT, Color = C.dim, ZIndex = 104 }, tab)
    local bar = add("Square", { Visible = true, Filled = false, Thickness = 1, Color = C.line, Position = V2(x + 10, y + 14), Size = V2(PANEL_W - 20, 6), ZIndex = 104 }, tab)
    local fill = add("Square", { Visible = true, Filled = true, Color = C.accent, Position = V2(x + 11, y + 15), Size = V2(0, 4), ZIndex = 105 }, tab)

    local function refresh()
        local cur = GetFlag(flag)
        local alpha = math.clamp((cur - minimum) / math.max(maximum - minimum, 0.0001), 0, 1)
        fill.Size = V2((PANEL_W - 22) * alpha, 4)
        value.Text = string.format(decimals and ("%." .. decimals .. "f") or "%.0f", cur) .. (suffix or "")
    end
    refresh()
    OnFlag(flag, refresh)

    click(bar, function()
        local m = UserInputService:GetMouseLocation()
        local alpha = math.clamp((m.X - bar.Position.X) / math.max(bar.Size.X, 1), 0, 1)
        local raw = minimum + (maximum - minimum) * alpha
        if decimals == nil or decimals == 0 then raw = math.floor(raw + 0.5) end
        SetFlag(flag, raw)
        refresh()
    end, tab)
    bump(tab, x, 30)
end

local function dropdown(tab, x, label, flag, optionsFn)
    local y = nextY(tab, x)
    add("Text", { Visible = true, Text = label, Position = V2(x + 10, y - 1), Size = 11, Font = FONT, Color = C.text, ZIndex = 104 }, tab)
    local bar = add("Square", { Visible = true, Filled = false, Thickness = 1, Color = C.line, Position = V2(x + 10, y + 13), Size = V2(PANEL_W - 20, 15), ZIndex = 104 }, tab)
    local value = add("Text", { Visible = true, Text = "", Position = V2(x + 90, y + 14), Size = 11, Font = FONT, Color = C.text, ZIndex = 105 }, tab)
    local left = add("Text", { Visible = true, Text = "<", Position = V2(x + 16, y + 14), Size = 11, Font = FONT, Color = C.dim, ZIndex = 105 }, tab)
    local right = add("Text", { Visible = true, Text = ">", Position = V2(x + PANEL_W - 26, y + 14), Size = 11, Font = FONT, Color = C.dim, ZIndex = 105 }, tab)

    local function refresh() value.Text = tostring(GetFlag(flag)) end
    refresh()
    OnFlag(flag, refresh)

    local function step(dir)
        local opts = optionsFn()
        if not opts or #opts == 0 then return end
        local cur = GetFlag(flag)
        local idx = 1
        for i, v in ipairs(opts) do if v == cur then idx = i break end end
        idx = ((idx - 1 + dir) % #opts) + 1
        SetFlag(flag, opts[idx])
        refresh()
    end
    click(left, function() step(-1) end, tab)
    click(right, function() step(1) end, tab)
    bump(tab, x, 30)
end

local function button(tab, x, label, fn)
    local y = nextY(tab, x)
    local bar = add("Square", { Visible = true, Filled = false, Thickness = 1, Color = C.line, Position = V2(x + 10, y), Size = V2(PANEL_W - 20, 16), ZIndex = 104 }, tab)
    add("Text", { Visible = true, Text = label, Position = V2(x + 14, y + 1), Size = 11, Font = FONT, Color = C.text, ZIndex = 105 }, tab)
    click(bar, function() pcall(fn) end, tab)
    bump(tab, x, 20)
end

local function textbox(tab, x, label, flag, placeholder)
    local y = nextY(tab, x)
    add("Text", { Visible = true, Text = label, Position = V2(x + 10, y - 1), Size = 11, Font = FONT, Color = C.text, ZIndex = 104 }, tab)
    local bar = add("Square", { Visible = true, Filled = false, Thickness = 1, Color = C.line, Position = V2(x + 10, y + 13), Size = V2(PANEL_W - 20, 15), ZIndex = 104 }, tab)
    local val = add("Text", { Visible = true, Text = "", Position = V2(x + 14, y + 14), Size = 11, Font = FONT, Color = C.dim, ZIndex = 105 }, tab)
    local function refresh()
        local v = GetFlag(flag)
        val.Text = (v and v ~= "") and v or (placeholder or "")
        val.Color = (v and v ~= "") and C.text or C.dim
    end
    refresh()
    OnFlag(flag, refresh)
    click(bar, function()
        UI.typing = flag
        val.Text = (GetFlag(flag) or "") .. "|"
    end, tab)
    bump(tab, x, 30)
end

-- ===== pages =====
panel(LEFT_X, "visuals")
panel(RIGHT_X, "visuals")
toggle("visuals", LEFT_X, "player esp", "playerEsp_toggle", { bind = "players" })
toggle("visuals", LEFT_X, "teamcheck", "playerEsp_teamCheck")
toggle("visuals", LEFT_X, "name", "playerEsp_name", { color = "playerEsp_nameColour" })
toggle("visuals", LEFT_X, "box", "playerEsp_box", { color = "playerEsp_boxColour" })
toggle("visuals", LEFT_X, "healthbar", "playerEsp_healthbar")
toggle("visuals", LEFT_X, "distance", "playerEsp_distance", { color = "playerEsp_distanceColour" })
toggle("visuals", LEFT_X, "weapon", "playerEsp_weapon", { color = "playerEsp_weaponColour" })
toggle("visuals", LEFT_X, "skeleton", "playerEsp_skeleton", { color = "playerEsp_skeletonColour" })
toggle("visuals", LEFT_X, "player chams", "playerChams_toggle", { color = "playerChams_colour" })
slider("visuals", LEFT_X, "chams transparency", "playerChams_transparency", 0, 100, "%", 0)
toggle("visuals", LEFT_X, "corner box", "playerEsp_cornerBox")

toggle("visuals", RIGHT_X, "npc esp", "npcEsp_toggle")
toggle("visuals", RIGHT_X, "name", "npcEsp_name")
toggle("visuals", RIGHT_X, "box", "npcEsp_box")
toggle("visuals", RIGHT_X, "healthbar", "npcEsp_healthbar")
toggle("visuals", RIGHT_X, "distance", "npcEsp_distance")
toggle("visuals", RIGHT_X, "soldier", "npcEsp_soldier", { color = "npcEsp_soldierColour" })
toggle("visuals", RIGHT_X, "deer", "npcEsp_deer", { color = "npcEsp_deerColour" })
toggle("visuals", RIGHT_X, "bear", "npcEsp_bear", { color = "npcEsp_bearColour" })
toggle("visuals", RIGHT_X, "boar", "npcEsp_boar", { color = "npcEsp_boarColour" })
slider("visuals", RIGHT_X, "max distance", "npcEsp_maxDistance", 400, 7500, " studs", 0)

panel(LEFT_X, "entity")
panel(RIGHT_X, "entity")
toggle("entity", LEFT_X, "entity esp", "entityEsp_toggle")
toggle("entity", LEFT_X, "box", "entityEsp_box")
toggle("entity", LEFT_X, "name", "entityEsp_name")
toggle("entity", LEFT_X, "distance", "entityEsp_distance")
toggle("entity", LEFT_X, "stone", "entityEsp_stone", { color = "entityEsp_stoneColour" })
toggle("entity", LEFT_X, "sulfur", "entityEsp_sulfur", { color = "entityEsp_sulfurColour" })
toggle("entity", LEFT_X, "metal", "entityEsp_metal", { color = "entityEsp_metalColour" })
toggle("entity", LEFT_X, "ore", "entityEsp_ore", { color = "entityEsp_oreColour" })
toggle("entity", LEFT_X, "tree", "entityEsp_tree", { color = "entityEsp_treeColour" })
toggle("entity", LEFT_X, "cactus", "entityEsp_cactus", { color = "entityEsp_cactusColour" })
toggle("entity", LEFT_X, "node (any)", "entityEsp_node", { color = "entityEsp_nodeColour" })
slider("entity", LEFT_X, "max distance", "entityEsp_maxDistance", 400, 7500, " studs", 0)

toggle("entity", RIGHT_X, "loot", "entityEsp_loot", { color = "entityEsp_lootColour" })
toggle("entity", RIGHT_X, "barrel", "entityEsp_barrel", { color = "entityEsp_barrelColour" })
toggle("entity", RIGHT_X, "barrel red", "entityEsp_barrelRed", { color = "entityEsp_barrelRedColour" })
toggle("entity", RIGHT_X, "loot crate", "entityEsp_lootCrate", { color = "entityEsp_lootCrateColour" })
toggle("entity", RIGHT_X, "loot sack", "entityEsp_lootSack", { color = "entityEsp_lootSackColour" })
toggle("entity", RIGHT_X, "military crate", "entityEsp_militaryCrate", { color = "entityEsp_militaryCrateColour" })
toggle("entity", RIGHT_X, "locked crate", "entityEsp_lockedCrate", { color = "entityEsp_lockedCrateColour" })
toggle("entity", RIGHT_X, "chest / cupboard", "entityEsp_chest", { color = "entityEsp_chestColour" })
toggle("entity", RIGHT_X, "deployable", "entityEsp_deployable", { color = "entityEsp_deployableColour" })
toggle("entity", RIGHT_X, "world item", "entityEsp_worldItem", { color = "entityEsp_worldItemColour" })
toggle("entity", RIGHT_X, "airdrop", "entityEsp_airdrop", { color = "entityEsp_airdropColour" })
toggle("entity", RIGHT_X, "minicopter", "entityEsp_minicopter", { color = "entityEsp_minicopterColour" })
toggle("entity", RIGHT_X, "boat", "entityEsp_boat", { color = "entityEsp_boatColour" })
toggle("entity", RIGHT_X, "pickup", "entityEsp_pickup", { color = "entityEsp_pickupColour" })

panel(LEFT_X, "local")
toggle("local", LEFT_X, "body chams", "localChams_toggle", { color = "localChams_colour" })
slider("local", LEFT_X, "transparency", "localChams_transparency", 0, 100, "%", 0)
dropdown("local", LEFT_X, "material", "localChams_material", function() return { "forcefield", "neon", "smoothplastic", "glass", "ice" } end)
toggle("local", LEFT_X, "arm chams", "localArmChams_toggle", { color = "localArmChams_colour" })
toggle("local", LEFT_X, "weapon chams", "localWeaponChams_toggle", { color = "localWeaponChams_colour" })
toggle("local", LEFT_X, "third person", "thirdperson_toggle")
slider("local", LEFT_X, "third person distance", "thirdperson_distance", 4, 40, " studs", 0)

panel(LEFT_X, "combat")
toggle("combat", LEFT_X, "aimbot", "aimbot_toggle", { bind = "aimbot" })
slider("combat", LEFT_X, "fov", "aimbot_fov", 10, 600, "px", 0)
slider("combat", LEFT_X, "smoothing", "aimbot_smoothing", 1, 20, "", 1)
toggle("combat", LEFT_X, "prediction", "aimbot_prediction")
toggle("combat", LEFT_X, "silent aim", "silentAim_toggle")
slider("combat", LEFT_X, "hitchance", "silentAim_hitchance", 1, 100, "%", 0)
toggle("combat", LEFT_X, "force hit", "silentAim_instantHit")
toggle("combat", LEFT_X, "manipulation", "silentAim_manipulation")
slider("combat", LEFT_X, "manipulation distance", "silentAim_manipulationDistance", 1, 8, " studs", 0)
toggle("combat", LEFT_X, "desync", "desync_toggle")
slider("combat", LEFT_X, "desync angle", "desync_angle", 0, 180, "°", 0)
dropdown("combat", LEFT_X, "emote", "emote_sel", function() return { "Zombie", "Take the L", "Floppy Fly" } end)
button("combat", LEFT_X, "play emote", function() PlayEmote(GetFlag("emote_sel")) end)
toggle("combat", LEFT_X, "hitmarkers", "hitmarkers_toggle")

panel(LEFT_X, "ui")
textbox("ui", LEFT_X, "config name", "config_name", "name")
button("ui", LEFT_X, "create config", function()
    local name = GetFlag("config_name")
    if not name or name == "" then return end
    if makefolder then pcall(makefolder, "PulsarOne"); pcall(makefolder, "PulsarOne/configs") end
    if writefile and HttpService then
        local out = {}
        for k, v in pairs(Flags) do
            if typeof(v) == "Color3" then
                out[k] = { __c = true, r = v.R, g = v.G, b = v.B }
            else
                out[k] = v
            end
        end
        local ok, json = pcall(function() return HttpService:JSONEncode(out) end)
        if ok then pcall(writefile, "PulsarOne/configs/" .. name .. ".json", json) end
    end
end)
button("ui", LEFT_X, "load config", function()
    local name = GetFlag("config_name")
    if not name or name == "" then return end
    if readfile then
        local ok, data = pcall(readfile, "PulsarOne/configs/" .. name .. ".json")
        if ok and data then
            local ok2, tbl = pcall(function() return HttpService:JSONDecode(data) end)
            if ok2 and type(tbl) == "table" then
                for k, v in pairs(tbl) do
                    if type(v) == "table" and v.__c then
                        SetFlag(k, Color3.new(v.r, v.g, v.b))
                    elseif Flags[k] ~= nil then
                        SetFlag(k, v)
                    end
                end
            end
        end
    end
end)
button("ui", LEFT_X, "delete config", function()
    local name = GetFlag("config_name")
    if name and name ~= "" and delfile then
        pcall(delfile, "PulsarOne/configs/" .. name .. ".json")
    end
end)
toggle("ui", LEFT_X, "keybind list", "keybindList_toggle")
toggle("ui", LEFT_X, "moderator list", "staffDetector_toggle")

-- initial visibility
for tabName, list in pairs(UI.groups) do
    for _, obj in ipairs(list) do
        obj.Visible = UI.open and tabName == UI.tab
    end
end
for id, txt in pairs(tabTexts) do
    txt.Color = (id == UI.tab) and C.white or C.dim
end

local function setMenuOpen(open)
    UI.open = open
    genv.pulsarMenuOpen = open
    for _, o in ipairs(UI.base) do o.Visible = open end
    for tabName, list in pairs(UI.groups) do
        for _, o in ipairs(list) do
            o.Visible = open and tabName == UI.tab
        end
    end
end

-- input: clicks
UserInputService.InputBegan:Connect(function(input, processed)
    pcall(function()
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if not UI.open then return end
    local m = UserInputService:GetMouseLocation()
    for _, c in ipairs(UI.clicks) do
        if (c.tab == nil or c.tab == UI.tab) and within(m, c.obj.Position, clickSize(c.obj)) then
            pcall(c.fn)
            return
        end
    end
    end)
end)

UserInputService.InputEnded:Connect(function(input)
    pcall(function()
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            UI.drag = nil
        end
    end)
end)

-- input: keys (menu toggle, keybind capture, text typing)
UserInputService.InputBegan:Connect(function(input, processed)
    pcall(function()
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        if UI.listening and input.UserInputType == Enum.UserInputType.MouseButton2 then
            Keybinds[UI.listening] = "MouseButton2"
            UI.listening = nil
            saveKeybinds()
        end
        return
    end
    local code = input.KeyCode

    if UI.typing then
        if code == Enum.KeyCode.Backspace then
            local cur = GetFlag(UI.typing) or ""
            SetFlag(UI.typing, string.sub(cur, 1, math.max(#cur - 1, 0)))
            return
        elseif code == Enum.KeyCode.Return or code == Enum.KeyCode.Escape then
            UI.typing = nil
            return
        elseif code == Enum.KeyCode.Space then
            SetFlag(UI.typing, (GetFlag(UI.typing) or "") .. " ")
            return
        end
        return
    end

    if UI.listening then
        if code == Enum.KeyCode.Escape or code == Enum.KeyCode.Backspace then
            Keybinds[UI.listening] = nil
        else
            Keybinds[UI.listening] = code.Name
        end
        UI.listening = nil
        saveKeybinds()
        return
    end

    if code == keyCodeFromName(Keybinds.menu) then
        setMenuOpen(not UI.open)
        return
    end
    if processed then return end

    for id, flag in pairs(KeybindActions) do
        local bound = keyCodeFromName(Keybinds[id])
        if bound and code == bound then
            SetFlag(flag, not GetFlag(flag))
            return
        end
    end
    end)
end)

-- drag update
RunService.RenderStepped:Connect(function()
    pcall(function()
        if UI.drag then
            local m = UserInputService:GetMouseLocation()
            local delta = m - UI.drag
            UI.drag = m
            for _, o in ipairs(UI.objs) do
                if o.From ~= nil then
                    o.From = o.From + delta
                    o.To = o.To + delta
                elseif o.Position ~= nil then
                    o.Position = o.Position + delta
                end
            end
        end
    end)
end)

-- character keys for textbox typing
UserInputService.InputBegan:Connect(function(input)
    pcall(function()
        if not UI.typing then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local name = input.KeyCode.Name
        local char = nil
        if #name == 1 then
            char = name:lower()
        elseif name == "Space" then
            char = " "
        elseif name:match("^LeftShift$") or name:match("^RightShift$") then
            return
        end
        if char then
            SetFlag(UI.typing, (GetFlag(UI.typing) or "") .. char)
        end
    end)
end)


if getgenv then getgenv().pulsarFustUI = true end

-- ============================================================
-- EXPORT API
-- ============================================================
_G.PulsarOne = {
    Flags = Flags,
    GetFlag = GetFlag,
    SetFlag = SetFlag,
    GetNPCs = GetNPCs,
    GetStaffList = function() return staffList end,
    GetPlayerArmour = GetPlayerArmour,
    PlayHitSound = PlayHitSound,
    DrawHitmarker = DrawHitmarker,
    CreateBulletTracer = CreateBulletTracer,
    staffList = staffList,
    NPC_SETTINGS = NPC_SETTINGS,
    ENTITY_SETTINGS = ENTITY_SETTINGS,
}

if getgenv then
    getgenv().pulsarOne_loaded = true
end

end

do
    local ok, err = pcall(__pulsarMain)
    if not ok and getgenv then
        getgenv().pulsarFustError = tostring(err)
    end
end
