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

-- text, its size setting
local TEXTS = {
    { get = function() return MinimapZoneText end, size = "zone" },
    { get = function() return TimeManagerClockTicker end, size = "clock" },
    { get = function()
        local pc = MinimapCluster.MinimapContainer.PlayerCoords
        return pc and pc.CoordText
    end, size = "coords" },
}

-- Blizzard's own font of each text, kept before the first change and put
-- back exactly when TidyMap is turned off
local saved = {}
local function Save(fs)
    if saved[fs] then return end
    local file, size, flags = fs:GetFont()
    saved[fs] = { object = fs:GetFontObject(), file = file, size = size, flags = flags }
end
local function Restore(fs)
    local s = saved[fs]
    if not s then return end
    if s.object then fs:SetFontObject(s.object) end
    if s.file then fs:SetFont(s.file, s.size, s.flags or "") end
end

local barAlpha   -- Blizzard's own, kept before the first change
local function ZoneBar(shown)
    local b = MinimapCluster.ZoneTextButton
    local t = b and b.StateTexture
    if not t then return end
    barAlpha = barAlpha or t:GetAlpha()
    t:SetAlpha(shown and barAlpha or 0)
end

local function Apply()
    local t = ns.P.texts
    for _, x in ipairs(TEXTS) do
        local fs = x.get()
        if fs then
            Save(fs)
            if On() then
                Flaty.SetFontFile(fs, t.font, t[x.size], t.outline)
            else
                Restore(fs)
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
