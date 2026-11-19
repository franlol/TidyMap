-------------------------------------------------------------------------------
-- TidyMap - Minimap icon (optional), a LibDBIcon button like any other
-- addon's: click opens the options, drag moves it around the map. Flat look,
-- clean mode, lock and the addon menu come from Buttons.lua, as for the rest.
-------------------------------------------------------------------------------

local ADDON, ns = ...
local L = ns.L

local DBI = LibStub("LibDBIcon-1.0")

-- LibDBIcon's settings (minimapPos, hide, lock), account-wide. Older
-- versions saved the position as "angle": same degrees, carried over.
local function Settings()
    local m = ns.db.icon
    if m.angle then
        m.minimapPos = m.angle
        m.angle = nil
    end
    return m
end

local broker = LibStub("LibDataBroker-1.1"):NewDataObject(ADDON, {
    type = "launcher",
    icon = "Interface\\AddOns\\TidyMap\\Media\\IconRound",
    OnClick = function() ns.ToggleOptions() end,
    OnTooltipShow = function(tt)
        tt:AddDoubleLine("TidyMap", ns.version, ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 0.5, 0.5, 0.5)
        tt:AddDoubleLine(L["Profile"], ns.profileName or "?", 0.7, 0.7, 0.7, 1, 1, 1)
        tt:AddLine(" ")
        tt:AddDoubleLine(L["Click"], L["Open the options"], 1, 0.82, 0, 1, 1, 1)
    end,
})

local function Start()
    if broker and not DBI:IsRegistered(ADDON) then
        DBI:Register(ADDON, broker, Settings())
    end
end

-- Shown unless hidden in the options (also with TidyMap off: the way back
-- to its options). Before Buttons.lua, which may then move it into the
-- addon menu.
local function Apply()
    DBI:Refresh(ADDON, Settings())
end

ns.Module(Start, Apply)
