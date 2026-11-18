-------------------------------------------------------------------------------
-- TidyMap - Blizzard's icons around the minimap (zone, clock, calendar,
-- tracking, mail, addon menu, day / night)
--
-- Each one sits on the edge of the map's shape, at an angle, and is shown,
-- shown on hover or hidden. Plain frame calls only: SetPoint to place them,
-- SetAlpha to fade them (so Blizzard's own Show / Hide still decide when
-- they exist, e.g. mail), and the places Blizzard re-anchors them are
-- followed with hooksecurefunc. Turned off, every icon gets its own place
-- back.
-------------------------------------------------------------------------------

local _, ns = ...
local Flaty = LibStub("LibFlatyUI-1.0")

-- Blizzard's ring around the day / night icon
local function DielRing(f)
    for _, r in ipairs({ f:GetRegions() }) do
        local atlas = r.GetAtlas and r:GetAtlas()
        if atlas and atlas:lower() == "ui-hud-minimap-frame-cycle" then return { r } end
    end
    return {}
end

-- key, name, the frame (it may not exist yet), the buttons inside it that
-- take the mouse, its text (text pieces: the flat look fits the text) and
-- Blizzard's decoration that the flat look hides
ns.ELEMENTS = {
    { key = "zone", name = "Zone",
        frame = function() return MinimapCluster.ZoneTextButton end,
        text = function() return MinimapZoneText end,
        decor = function(f) return { f.StateTexture } end },
    { key = "clock", name = "Clock",
        frame = function() return TimeManagerClockButton end,
        text = function() return TimeManagerClockTicker end },
    { key = "calendar", name = "Calendar",
        frame = function() return GameTimeFrame end },
    { key = "tracking", name = "Tracking",
        frame = function() return MinimapCluster.Tracking end,
        buttons = function(f) return { f.Button } end,
        decor = function(f) return { f.Background } end },
    { key = "mail", name = "Mail",
        frame = function() return MinimapCluster.IndicatorFrame end,
        buttons = function(f) return { f.MailFrame } end },
    { key = "compartment", name = "Addon menu",
        frame = function() return AddonCompartmentFrame end },
    { key = "daynight", name = "Day / night",
        frame = function() return MinimapCluster.DielFrame end,
        decor = DielRing },
    { key = "coords", name = "Coordinates",
        frame = function() return MinimapCluster.MinimapContainer.PlayerCoords end,
        text = function(f) return f.CoordText end },
}
local BY_KEY = {}
for _, e in ipairs(ns.ELEMENTS) do BY_KEY[e.key] = e end

local saved = {}       -- [frame] = Blizzard's own points and mouse
local editing = false  -- the options window is open: every icon visible
local alpha = 0        -- current alpha of the "on hover" icons

local function On() return ns.P and ns.P.enabled end

function ns.ElementFrame(key)
    local e = BY_KEY[key]
    return e and e.frame()
end

-- Effective mode: Clean mode turns "show" into "hover"
-- Clean mode turns "show" into "hover" (icons and header pieces alike)
function ns.EffectiveMode(m)
    if m == "show" and ns.P.clean then return "hover" end
    return m
end

-- Blizzard's zone and clock give way to TidyMap's header while it is on
function ns.InHeader(key)
    return (key == "zone" or key == "clock") and ns.P.header.on
end

function ns.ElementMode(key)
    if ns.InHeader(key) then return "hide" end
    return ns.EffectiveMode(ns.P.elements[key].mode)
end

-- Other frames that fade like the "on hover" icons (the header pieces):
-- { frame, mode = function() return "show" / "hover" / "hide" end }
ns.faders = {}
function ns.HoverAlpha() return alpha end
function ns.IsEditing() return editing end

local function Save(f)
    if saved[f] then return end
    local points = {}
    for i = 1, f:GetNumPoints() do points[i] = { f:GetPoint(i) } end
    saved[f] = { points = points, mouse = f:IsMouseEnabled(), alpha = f:GetAlpha(), scale = f:GetScale() }
end

local function Restore(f)
    local s = saved[f]
    if not s then return end
    f:SetScale(s.scale or 1)
    f:ClearAllPoints()
    for _, p in ipairs(s.points) do f:SetPoint(unpack(p)) end
    f:SetAlpha(s.alpha or 1)
end

-------------------------------------------------------------------------------
-- Look: Blizzard's art, or flat: a dark plate in the map's corner shape
-- with a thin border in the map's border color, under Blizzard's icon (two
-- textures added to the icon, so they fade and scale with it). Blizzard's
-- decoration (the tracking disc, the day / night ring, the zone bar) fades.
-------------------------------------------------------------------------------
local plates = {}       -- [frame] = { bg, edge }
local decorAlpha = {}   -- [texture] = Blizzard's own alpha

local function Decor(e, f, shown)
    if not e.decor then return end
    for _, t in ipairs(e.decor(f)) do
        if t then
            decorAlpha[t] = decorAlpha[t] or t:GetAlpha()
            t:SetAlpha(shown and decorAlpha[t] or 0)
        end
    end
end

local function PaintPlate(e, f, flat)
    local p = plates[f]
    if not flat then
        if p then p.bg:Hide() p.edge:Hide() end
        return
    end
    if not p then
        p = { edge = f:CreateTexture(nil, "BACKGROUND", nil, -8), bg = f:CreateTexture(nil, "BACKGROUND", nil, -7) }
        plates[f] = p
    end
    -- the size of the text for text pieces, of the icon for the rest
    local w, h, anchor
    local text = e.text and e.text(f)
    if text then
        local tw = text:GetStringWidth() or 0
        if tw < 1 then
            p.bg:Hide() p.edge:Hide()
            return
        end
        w, h, anchor = tw + 12, (text:GetStringHeight() or 10) + 6, text
    else
        local fw, fh = f:GetSize()
        w, h, anchor = fw + 4, fh + 4, f
    end
    local mask = Flaty.GetShape(Flaty.Rounded(ns.P.corners)).mask
    p.bg:SetTexture(mask)
    p.bg:SetVertexColor(0.05, 0.05, 0.06, 0.9)
    p.bg:SetSize(w, h)
    p.bg:ClearAllPoints()
    p.bg:SetPoint("CENTER", anchor, "CENTER")
    p.bg:Show()
    local c = ns.BorderColor()
    p.edge:SetShown(c ~= nil)
    if c then
        p.edge:SetTexture(mask)
        p.edge:SetVertexColor(c[1], c[2], c[3], c[4])
        p.edge:SetSize(w + 2, h + 2)
        p.edge:ClearAllPoints()
        p.edge:SetPoint("CENTER", anchor, "CENTER")
    end
end

local function SetMouse(e, f, on)
    local list = { f }
    if e.buttons then
        for _, b in ipairs(e.buttons(f)) do list[#list + 1] = b end
    end
    for _, b in ipairs(list) do
        if b then
            if not saved[b] then saved[b] = { mouse = b:IsMouseEnabled() } end
            b:EnableMouse(on and saved[b].mouse or false)
        end
    end
end

-- The icon's center on the edge, in its own units (it can have another
-- scale than the map: Edit Mode sizes them apart)
local function Place(e, f)
    local s = ns.P.elements[e.key]
    local shape = Flaty.Rounded(ns.P.corners)
    local x, y = Flaty.ShapeEdge(shape, s.angle, Minimap:GetWidth() / 2, Minimap:GetHeight() / 2, s.dist)
    local k = Minimap:GetEffectiveScale() / f:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint("CENTER", Minimap, "CENTER", x * k, y * k)
end

local function Paint(e, f)
    local mode = ns.ElementMode(e.key)
    if editing then
        f:SetAlpha(mode == "hide" and 0.35 or 1)
    elseif mode == "show" then
        f:SetAlpha(1)
    elseif mode == "hover" then
        f:SetAlpha(alpha)
    else
        f:SetAlpha(0)
    end
    SetMouse(e, f, editing or mode ~= "hide")
end

local function ApplyOne(e)
    local f = e.frame()
    if not f then return end
    Save(f)
    if On() then
        local s = ns.P.elements[e.key]
        f:SetScale((saved[f].scale or 1) * (s.size or 100) / 100)
        Place(e, f)
        Paint(e, f)
        Decor(e, f, s.look ~= "flat")
        PaintPlate(e, f, s.look == "flat")
    else
        Restore(f)
        SetMouse(e, f, true)
        Decor(e, f, true)
        PaintPlate(e, f, false)
    end
    if ns.OnElementPlaced then ns.OnElementPlaced(e.key, f) end
end

function ns.ApplyElement(key)
    local e = BY_KEY[key]
    if e then ApplyOne(e) end
end

local function Apply()
    for _, e in ipairs(ns.ELEMENTS) do ApplyOne(e) end
end
ns.ApplyElements = Apply

-- The options window open: every icon visible (hidden ones faint), so they
-- can be dragged
function ns.SetElementsEditing(on)
    editing = on and true or false
    Apply()
    if ns.ApplyHeader then ns.ApplyHeader() end
end

-------------------------------------------------------------------------------
-- "On hover": fade in while the mouse is over the map or its icons
-------------------------------------------------------------------------------
local MARGIN = 28     -- around the map, where the icons sit
local FADE = 0.2      -- seconds for a full fade

local function MouseNear()
    if Minimap:IsMouseOver(MARGIN, -MARGIN, -MARGIN, MARGIN) then return true end
    for _, e in ipairs(ns.ELEMENTS) do
        local f = e.frame()
        if f and f:IsVisible() and f:IsMouseOver() then return true end
    end
    for _, x in ipairs(ns.faders) do
        if x.frame:IsVisible() and x.frame:IsMouseOver() then return true end
    end
    return false
end

local driver = CreateFrame("Frame")
local wait = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    if not On() or editing then return end
    wait = wait + elapsed
    if wait < 0.05 then return end
    local step = wait / FADE
    wait = 0
    local target = MouseNear() and 1 or 0
    if alpha == target then return end
    alpha = target > alpha and math.min(1, alpha + step) or math.max(0, alpha - step)
    for _, e in ipairs(ns.ELEMENTS) do
        local f = e.frame()
        if f and ns.ElementMode(e.key) == "hover" then f:SetAlpha(alpha) end
    end
    for _, x in ipairs(ns.faders) do
        if x.mode() == "hover" then x.frame:SetAlpha(alpha) end
    end
end)

-------------------------------------------------------------------------------
-- Blizzard places some of them again: after the header moves (Edit Mode),
-- the map changes size, the clock loads, or Edit Mode closes
-------------------------------------------------------------------------------
local function Again()
    if On() then Apply() end
end

local function Start()
    for _, name in ipairs({ "SetHeaderUnderneath", "SetEditModeScale", "UpdateMinimapConfig" }) do
        if MinimapCluster[name] then hooksecurefunc(MinimapCluster, name, Again) end
    end
    -- after Edit Mode closes. A post-hook, not an EventRegistry callback: a
    -- callback would run inside Blizzard's own exit and taint what follows
    -- (protected actions then get blocked, blamed on TidyMap)
    if EditModeManagerFrame and EditModeManagerFrame.ExitEditMode then
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", Again)
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, event, name)
        -- the clock exists once its addon loads
        if event == "PLAYER_ENTERING_WORLD" or name == "Blizzard_TimeManager" then Apply() end
    end)
    -- flat look under texts (zone, clock, coordinates): it follows the text
    C_Timer.NewTicker(1, function()
        if not On() then return end
        for _, e in ipairs(ns.ELEMENTS) do
            local f = e.text and e.frame()
            if f and ns.P.elements[e.key].look == "flat" then PaintPlate(e, f, true) end
        end
    end)
end

ns.Module(Start, Apply)
