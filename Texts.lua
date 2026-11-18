-------------------------------------------------------------------------------
-- TidyMap - Texts: Blizzard's zone name, clock and coordinates in one font
-- (a size each), and the bar behind the zone name.
-- Blizzard keeps writing and coloring them (the zone color tells PvP);
-- TidyMap only sets the font. Turned off, they get Blizzard's fonts back.
--
-- No "who pinged" text: on Forever the ping event (MINIMAP_PING) is only for
-- Blizzard's UI (listening to it blocks an action).
-------------------------------------------------------------------------------

local _, ns = ...
local Flaty = LibStub("LibFlatyUI-1.0")

local function On() return ns.P and ns.P.enabled end

-- text, its size setting, Blizzard's own font
local TEXTS = {
    { get = function() return MinimapZoneText end, size = "zone", blizzard = "GameFontHighlightSmall" },
    { get = function() return TimeManagerClockTicker end, size = "clock", blizzard = "WhiteNormalNumberFont" },
    { get = function()
        local pc = MinimapCluster.MinimapContainer.PlayerCoords
        return pc and pc.CoordText
    end, size = "coords", blizzard = "GameFontHighlightSmall" },
}

local function ZoneBar(shown)
    local b = MinimapCluster.ZoneTextButton
    if b and b.StateTexture then b.StateTexture:SetAlpha(shown and 1 or 0) end
end

local function Apply()
    local t = ns.P.texts
    for _, x in ipairs(TEXTS) do
        local fs = x.get()
        if fs then
            if On() then
                Flaty.SetFontFile(fs, t.font, t[x.size], t.outline)
            else
                fs:SetFontObject(x.blizzard)
            end
        end
    end
    ZoneBar(not On() or t.zoneBar)
end

local function Start()
    -- the clock exists once its addon loads
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(_, _, name)
        if name == "Blizzard_TimeManager" then Apply() end
    end)
end

ns.Module(Start, Apply)
