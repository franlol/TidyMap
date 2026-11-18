-------------------------------------------------------------------------------
-- TidyMap - Texts: Blizzard's zone name, clock and coordinates in one font
-- (a size each), the bar behind the zone name, and who pinged the map.
-- Blizzard keeps writing and coloring them (the zone color tells PvP);
-- TidyMap only sets the font. Turned off, they get Blizzard's fonts back.
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

-------------------------------------------------------------------------------
-- Ping: the name of who clicked the map, in their class color
-------------------------------------------------------------------------------
local ping = CreateFrame("Frame", nil, Minimap)
ping:SetSize(1, 1)
ping:SetPoint("TOP", Minimap, "TOP", 0, -10)
ping:SetFrameLevel(Minimap:GetFrameLevel() + 20)
ping:Hide()
local pingText = ping:CreateFontString(nil, "OVERLAY")
pingText:SetPoint("TOP")
pingText:SetShadowOffset(1, -1)   -- readable over the map
pingText:SetShadowColor(0, 0, 0, 1)
local SHOW, FADE = 2.5, 0.6
local shown = 0

ping:SetScript("OnUpdate", function(self, elapsed)
    shown = shown + elapsed
    if shown > SHOW + FADE then
        self:Hide()
    elseif shown > SHOW then
        self:SetAlpha(1 - (shown - SHOW) / FADE)
    end
end)

local function ShowPing(unit)
    if not On() or not ns.P.texts.ping or not unit then return end
    local name = UnitName(unit)
    if not name then return end
    local _, class = UnitClass(unit)
    local c = class and C_ClassColor and C_ClassColor.GetClassColor(class)
    pingText:SetText(name)
    if c then pingText:SetTextColor(c.r, c.g, c.b) else pingText:SetTextColor(1, 1, 1) end
    shown = 0
    ping:SetAlpha(1)
    ping:Show()
end

-- in some places the game hides who it is (a secret value): then nothing
local function OnPing(unit)
    pcall(ShowPing, unit)
end

-------------------------------------------------------------------------------
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
    Flaty.SetFontFile(pingText, t.font, t.pingSize, t.outline)
    if not On() or not t.ping then ping:Hide() end
end

local function Start()
    -- the clock exists once its addon loads
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(_, _, name)
        if name == "Blizzard_TimeManager" then Apply() end
    end)
    -- pings: newer clients only hand this event to callbacks
    if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid("MINIMAP_PING")
        and ping.RegisterEventCallback then
        ping:RegisterEventCallback("MINIMAP_PING", function(_, unit) OnPing(unit) end)
    else
        local p = CreateFrame("Frame")
        p:RegisterEvent("MINIMAP_PING")
        p:SetScript("OnEvent", function(_, _, unit) OnPing(unit) end)
    end
end

ns.Module(Start, Apply)
