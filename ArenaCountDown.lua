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
local ArenaCountDown = LibStub:NewLibrary(MAJOR, MINOR)
local L
ArenaCountDown.version_major_num = 1
ArenaCountDown.version_minor_num = 0.00
ArenaCountDown.version_num = ArenaCountDown.version_major_num + ArenaCountDown.version_minor_num
ArenaCountDown.version_releaseType = RELEASE_TYPES.release
ArenaCountDown.version = PREFIX .. string.format("%.2f", ArenaCountDown.version_num) .. "-" .. ArenaCountDown.version_releaseType

ArenaCountDown.modules = {}
setmetatable(ArenaCountDown, {
    __tostring = function()
        return MAJOR
    end
})

function ArenaCountDown:Print(...)
    local text = "|cff0384fcArenaCountDown|r:"
    local val
    for i = 1, select("#", ...) do
        val = select(i, ...)
        if (type(val) == 'boolean') then val = val and "true" or false end
        text = text .. " " .. tostring(val)
    end
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

function ArenaCountDown:Warn(...)
    local text = "|cfff29f05ArenaCountDown|r:"
    local val
    for i = 1, select("#", ...) do
        val = select(i, ...)
        if (type(val) == 'boolean') then val = val and "true" or false end
        text = text .. " " .. tostring(val)
    end
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

function ArenaCountDown:Error(...)
    local text = "|cfffc0303ArenaCountDown|r:"
    local val
    for i = 1, select("#", ...) do
        val = select(i, ...)
        if (type(val) == 'boolean') then val = val and "true" or false end
        text = text .. " " .. tostring(val)
    end
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

function ArenaCountDown:Debug(lvl, ...)
    if ArenaCountDown.debug then
        if lvl == "INFO" then
            ArenaCountDown:Print(...)
        elseif lvl == "WARN" then
            ArenaCountDown:Warn(...)
        elseif lvl == "ERROR" then
            ArenaCountDown:Error(...)
        end
    end
end

ArenaCountDown.events = CreateFrame("Frame")
ArenaCountDown.events.registered = {}
ArenaCountDown.events:RegisterEvent("PLAYER_LOGIN")
ArenaCountDown.events:SetScript("OnEvent", function(self, event, ...)
    if (type(ArenaCountDown[event]) == "function") then
        ArenaCountDown[event](ArenaCountDown, ...)
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
function ArenaCountDown:IterModules()
    return pairsByPrio(self.modules)
end

function ArenaCountDown:Call(module, func, ...)
    if (type(module) == "string") then
        module = self.modules[module]
    end

    if (type(module[func]) == "function") then
        module[func](module, ...)
    end
end
function ArenaCountDown:SendMessage(message, ...)
    for _, module in self:IterModules() do
        self:Call(module, module.messages[message], ...)
    end
end

function ArenaCountDown:NewModule(name, priority, defaults)
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

function ArenaCountDown:DeleteUnknownOptions(tbl, refTbl, str)
    if str == nil then
        str = "ArenaCountDown.db"
    end
    for k,v in pairs(tbl) do
        if refTbl[k] == nil then
            ArenaCountDown:Debug("INFO", "SavedVariable deleted:", str .. "." .. k, "not found!")
            tbl[k] = nil
        else
            if type(v) ~= type(refTbl[k]) then
                ArenaCountDown:Debug("INFO", "SavedVariable deleted:", str .. "." .. k, "type error!", "Expected", type(refTbl[k]), "but found", type(v))
                tbl[k] = nil
            elseif type(v) == "table" then
                ArenaCountDown:DeleteUnknownOptions(v, refTbl[k], str .. "." .. k)
            end
        end
    end
end

function ArenaCountDown:OnInitialize()
    if IsAddOnLoaded("Gladdy") and LibStub("Gladdy").db.countdown then
        self:Error("not loaded because Gladdy's ArenaCountDown is enabled")
        return
    end
    self:Print("version", string.format("%.2f", ArenaCountDown.version_num) .. "-" .. ArenaCountDown.version_releaseType, "loaded.")

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

function ArenaCountDown:OnProfileReset()
    self.db = self.dbi.profile
    LibStub("AceConfigRegistry-3.0"):NotifyChange("ArenaCountDown")
end

function ArenaCountDown:OnProfileChanged()
    self.db = self.dbi.profile
    LibStub("AceConfigRegistry-3.0"):NotifyChange("ArenaCountDown")
end

function ArenaCountDown:OnEnable()
    self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function ArenaCountDown:RegisterEvent(event, func)
    self.events.registered[event] = func or event
    self.events:RegisterEvent(event)
end
function ArenaCountDown:UnregisterEvent(event)
    self.events.registered[event] = nil
    self.events:UnregisterEvent(event)
end
function ArenaCountDown:UnregisterAllEvents()
    self.events.registered = {}
    self.events:UnregisterAllEvents()
end

---------------------------

-- EVENTS

---------------------------

function ArenaCountDown:PLAYER_LOGIN()
    self:OnInitialize()
    self:OnEnable()
end

function ArenaCountDown:PLAYER_LOGOUT()
    self:DeleteUnknownOptions(self.db, self.defaults.profile)
end

function ArenaCountDown:PLAYER_ENTERING_WORLD()

end

function ArenaCountDown:UPDATE_BATTLEFIELD_STATUS(_, index)
    local status, mapName, instanceID, levelRangeMin, levelRangeMax, teamSize, isRankedArena, suspendedQueue, bool, queueType = GetBattlefieldStatus(index)
    local instanceType = select(2, IsInInstance())
    ArenaCountDown:Debug("INFO", "UPDATE_BATTLEFIELD_STATUS", instanceType, status, teamSize)
    if ((instanceType == "arena" or GetNumArenaOpponents() > 0) and status == "active" and teamSize > 0) then
        self.curBracket = teamSize
        self:JoinedArena()
    end
end

---------------------------

-- ARENA JOINED

---------------------------

function ArenaCountDown:JoinedArena()
    self:SendMessage("JOINED_ARENA")
end

---------------------------

-- RESET FUNCTIONS (ARENA LEAVE)

---------------------------

function ArenaCountDown:Reset()
    for _, module in self:IterModules() do
        self:Call(module, "Reset")
    end
end

---------------------------

-- TEST

---------------------------

function ArenaCountDown:Test()
    self.testing = true
    for _, module in self:IterModules() do
        self:Call(module, "TestOnce")
    end
end

