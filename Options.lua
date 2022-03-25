local type, pairs, tinsert, tsort = type, pairs, table.insert, table.sort

local ArenaCountDown = LibStub("ArenaCountDown")
local L = ArenaCountDown.L

ArenaCountDown.defaults = {
    profile = {},
}

function ArenaCountDown:option(params)
    local defaults = {
        get = function(info)
            local key = info.arg or info[#info]
            return ArenaCountDown.dbi.profile[key]
        end,
        set = function(info, value)
            local key = info.arg or info[#info]
            ArenaCountDown.dbi.profile[key] = value
            ArenaCountDown:UpdateFrame()
        end,
    }

    for k, v in pairs(params) do
        defaults[k] = v
    end

    return defaults
end

local function getOpt(info)
    local key = info.arg or info[#info]
    return ArenaCountDown.dbi.profile[key]
end
local function setOpt(info, value)
    local key = info.arg or info[#info]
    ArenaCountDown.dbi.profile[key] = value
    ArenaCountDown:UpdateFrame()
end

function ArenaCountDown:UpdateFrame()
    for _, v in self:IterModules() do
        self:Call(v, "UpdateFrame")
    end
    for _, v in self:IterModules() do
        self:Call(v, "UpdateFrameOnce")
    end
end

function ArenaCountDown:SetupModule(name, module, order)
    local options = module:GetOptions()
    if options then
        self.options.args[name] = {
            type = "group",
            name = L[name],
            desc = L[name] .. " " .. L["settings"],
            childGroups = "tab",
            order = order,
            args = {},
        }

        if (type(options) == "table") then
            self.options.args[name].args = options
            self.options.args[name].args.reset = {
                type = "execute",
                name = L["Reset module"],
                desc = L["Reset module to defaults"],
                order = 1,
                func = function()
                    for k, v in pairs(module.defaults) do
                        self.dbi.profile[k] = v
                    end

                    ArenaCountDown:UpdateFrame()
                    ArenaCountDown:SetupModule(name, module, order) -- For example click names are not reset by default
                end
            }
        else
            self.options.args[name].args.nothing = {
                type = "description",
                name = L["No settings"],
                desc = L["Module has no settings"],
                order = 1,
            }
        end
    end
end

local function pairsByKeys(t)
    local a = {}
    for k in pairs(t) do
        tinsert(a, k)
    end
    tsort(a, function(a, b) return L[a] < L[b] end)

    local i = 0
    return function()
        i = i + 1

        if (a[i] ~= nil) then
            return a[i], t[a[i]]
        else
            return nil
        end
    end
end

function ArenaCountDown:ShowOptions()
    InterfaceOptionsFrame_OpenToFrame("ArenaCountDown")
end

function ArenaCountDown:SetupOptions()
    self.options = {
        type = "group",
        name = L["ArenaCountDown"],
        plugins = {},
        childGroups = "tree",
        get = getOpt,
        set = setOpt,
        args = {
            test = {
                order = 2,
                width = 0.7,
                name = L["Test"],
                desc = L["Show Test frames"],
                type = "execute",
                func = function()
                    ArenaCountDown:Test()
                end,
            },
            hide = {
                order = 3,
                width = 0.7,
                name = L["Hide"],
                desc = L["Hide frames"],
                type = "execute",
                func = function()
                    ArenaCountDown:Reset()
                end,
            },
            reload = {
                order = 4,
                width = 0.7,
                name = L["ReloadUI"],
                desc = L["Reloads the UI"],
                type = "execute",
                func = function()
                    ReloadUI()
                end,
            },
            version = {
                order = 5,
                width = 1,
                type = "description",
                name = "     " .. ArenaCountDown.version
            },
        },
    }

    local order = 6
    for k, v in pairsByKeys(self.modules) do
        self:SetupModule(k, v, order)
        order = order + 1
    end

    local options = {
        name = L["ArenaCountDown"],
        type = "group",
        args = {
            load = {
                name = L["Load configuration"],
                desc = L["Load configuration options"],
                type = "execute",
                func = function()
                    HideUIPanel(InterfaceOptionsFrame)
                    HideUIPanel(GameMenuFrame)
                    LibStub("AceConfigDialog-3.0"):Open("ArenaCountDown")
                end,
            },
        },
    }

    self.options.plugins.profiles = { profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.dbi) }
    LibStub("AceConfig-3.0"):RegisterOptionsTable("ArenaCountDown_blizz", options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ArenaCountDown_blizz", "ArenaCountDown")
    LibStub("AceConfig-3.0"):RegisterOptionsTable("ArenaCountDown", self.options)

end