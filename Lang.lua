local setmetatable = setmetatable
local GetLocale = GetLocale

local L = {}

if (GetLocale() == "ruRU") then

end

LibStub("ArenaCountDown").L = setmetatable(L, {
    __index = function(t, k)
        return k
    end
})