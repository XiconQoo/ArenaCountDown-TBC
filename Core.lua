local LibStub = LibStub

local setmetatable = setmetatable
local type = type
local tostring = tostring
local select = select
local pairs = pairs
local tinsert = table.insert
local tsort = table.sort

local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
local CreateFrame = CreateFrame
local IsAddOnLoaded = IsAddOnLoaded
local GetBattlefieldStatus = GetBattlefieldStatus
local IsInInstance = IsInInstance
local GetNumArenaOpponents = GetNumArenaOpponents

local RELEASE_TYPES = { alpha = "Alpha", beta = "Beta", release = "Release"}
local PREFIX = "ArenaCountDown v"

---------------------------

-- CORE

---------------------------

local MAJOR, MINOR = "ArenaCountDown", 1
local Core = LibStub:NewLibrary(MAJOR, MINOR)
local L
Core.version_major_num = 1
Core.version_minor_num = 0.00
Core.version_num = Core.version_major_num + Core.version_minor_num
Core.version_releaseType = RELEASE_TYPES.release
Core.version = PREFIX .. string.format("%.2f", Core.version_num) .. "-" .. Core.version_releaseType

Core.modules = {}
setmetatable(Core, {
    __tostring = function()
        return MAJOR
    end
})

function Core:Print(...)
    local text = "|cff0384fcArenaCountDown|r:"
    local val
    for i = 1, select("#", ...) do
        val = select(i, ...)
        if (type(val) == 'boolean') then val = val and "true" or false end
        text = text .. " " .. tostring(val)
    end
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

function Core:Warn(...)
    local text = "|cfff29f05ArenaCountDown|r:"
    local val
    for i = 1, select("#", ...) do
        val = select(i, ...)
        if (type(val) == 'boolean') then val = val and "true" or false end
        text = text .. " " .. tostring(val)
    end
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

function Core:Error(...)
    local text = "|cfffc0303ArenaCountDown|r:"
    local val
    for i = 1, select("#", ...) do
        val = select(i, ...)
        if (type(val) == 'boolean') then val = val and "true" or false end
        text = text .. " " .. tostring(val)
    end
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

function Core:Debug(lvl, ...)
    if Core.debug then
        if lvl == "INFO" then
            Core:Print(...)
        elseif lvl == "WARN" then
            Core:Warn(...)
        elseif lvl == "ERROR" then
            Core:Error(...)
        end
    end
end

Core.events = CreateFrame("Frame")
Core.events.registered = {}
Core.events:RegisterEvent("PLAYER_LOGIN")
Core.events:SetScript("OnEvent", function(self, event, ...)
    if (type(Core[event]) == "function") then
        Core[event](Core, ...)
    end
end)

---------------------------

-- MODULE FUNCTIONS

---------------------------

local function pairsByPrio(t)
    local a = {}
    for k, v in pairs(t) do
        tinsert(a, { k, v.priority })
    end
    tsort(a, function(x, y)
        return x[2] > y[2]
    end)

    local i = 0
    return function()
        i = i + 1

        if (a[i] ~= nil) then
            return a[i][1], t[a[i][1]]
        else
            return nil
        end
    end
end
function Core:IterModules()
    return pairsByPrio(self.modules)
end

function Core:Call(module, func, ...)
    if (type(module) == "string") then
        module = self.modules[module]
    end

    if (type(module[func]) == "function") then
        module[func](module, ...)
    end
end
function Core:SendMessage(message, ...)
    for _, module in self:IterModules() do
        self:Call(module, module.messages[message], ...)
    end
end

function Core:NewModule(name, priority, defaults)
    local module = CreateFrame("Frame")
    module.name = name
    module.priority = priority or 0
    module.defaults = defaults or {}
    module.messages = {}

    module.RegisterMessages = function(self, ...)
        for _,message in pairs({...}) do
            self.messages[message] = message
        end
    end

    module.RegisterMessage = function(self, message, func)
        self.messages[message] = func or message
    end

    module.UnregisterMessage = function(self, message)
        self.messages[message] = nil
    end

    module.UnregisterMessages = function(self, ...)
        for _,message in pairs({...}) do
            self.messages[message] = nil
        end
    end

    module.UnregisterAllMessages = function(self)
        for msg,_ in pairs(self.messages) do
            self.messages[msg] = nil
        end
    end

    module.GetOptions = function()
        return nil
    end

    for k, v in pairs(module.defaults) do
        self.defaults.profile[k] = v
    end

    self.modules[name] = module

    return module
end

---------------------------

-- INIT

---------------------------

function Core:DeleteUnknownOptions(tbl, refTbl, str)
    if str == nil then
        str = "ArenaCountDown.db"
    end
    for k,v in pairs(tbl) do
        if refTbl[k] == nil then
            Core:Debug("INFO", "SavedVariable deleted:", str .. "." .. k, "not found!")
            tbl[k] = nil
        else
            if type(v) ~= type(refTbl[k]) then
                Core:Debug("INFO", "SavedVariable deleted:", str .. "." .. k, "type error!", "Expected", type(refTbl[k]), "but found", type(v))
                tbl[k] = nil
            elseif type(v) == "table" then
                Core:DeleteUnknownOptions(v, refTbl[k], str .. "." .. k)
            end
        end
    end
end

function Core:OnInitialize()
    if IsAddOnLoaded("Gladdy") and LibStub("Gladdy").db.countdown then
        self:Error("not loaded because Gladdy's ArenaCountDown is enabled")
        return
    end
    self:Print("version", string.format("%.2f", Core.version_num) .. "-" .. Core.version_releaseType, "loaded.")

    self.dbi = LibStub("AceDB-3.0"):New("ACDXZ", self.defaults)
    self.dbi.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.dbi.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.dbi.RegisterCallback(self, "OnProfileReset", "OnProfileReset")
    self.db = self.dbi.profile

    L = self.L

    self:SetupOptions()

    for _, module in self:IterModules() do
        self:Call(module, "Initialize")
    end
end

function Core:OnProfileReset()
    self.db = self.dbi.profile
    LibStub("AceConfigRegistry-3.0"):NotifyChange("ArenaCountDown")
end

function Core:OnProfileChanged()
    self.db = self.dbi.profile
    LibStub("AceConfigRegistry-3.0"):NotifyChange("ArenaCountDown")
end

function Core:OnEnable()
    self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function Core:RegisterEvent(event, func)
    self.events.registered[event] = func or event
    self.events:RegisterEvent(event)
end
function Core:UnregisterEvent(event)
    self.events.registered[event] = nil
    self.events:UnregisterEvent(event)
end
function Core:UnregisterAllEvents()
    self.events.registered = {}
    self.events:UnregisterAllEvents()
end

---------------------------

-- EVENTS

---------------------------

function Core:PLAYER_LOGIN()
    self:OnInitialize()
    self:OnEnable()
end

function Core:PLAYER_LOGOUT()
    self:DeleteUnknownOptions(self.db, self.defaults.profile)
end

function Core:PLAYER_ENTERING_WORLD()

end

function Core:UPDATE_BATTLEFIELD_STATUS(_, index)
    local status, mapName, instanceID, levelRangeMin, levelRangeMax, teamSize, isRankedArena, suspendedQueue, bool, queueType = GetBattlefieldStatus(index)
    local instanceType = select(2, IsInInstance())
    Core:Debug("INFO", "UPDATE_BATTLEFIELD_STATUS", instanceType, status, teamSize)
    if ((instanceType == "arena" or GetNumArenaOpponents() > 0) and status == "active" and teamSize > 0) then
        self.curBracket = teamSize
        self:JoinedArena()
    end
end

---------------------------

-- ARENA JOINED

---------------------------

function Core:JoinedArena()
    self:SendMessage("JOINED_ARENA")
end

---------------------------

-- RESET FUNCTIONS (ARENA LEAVE)

---------------------------

function Core:Reset()
    for _, module in self:IterModules() do
        self:Call(module, "Reset")
    end
end

---------------------------

-- TEST

---------------------------

function Core:Test()
    self.testing = true
    for _, module in self:IterModules() do
        self:Call(module, "TestOnce")
    end
end

