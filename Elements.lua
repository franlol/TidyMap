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

-- key, name, the frame (it may not exist yet), the buttons inside it that
-- take the mouse
ns.ELEMENTS = {
    { key = "zone", name = "Zone",
        frame = function() return MinimapCluster.ZoneTextButton end },
    { key = "clock", name = "Clock",
        frame = function() return TimeManagerClockButton end },
    { key = "calendar", name = "Calendar",
        frame = function() return GameTimeFrame end },
    { key = "tracking", name = "Tracking",
        frame = function() return MinimapCluster.Tracking end,
        buttons = function(f) return { f.Button } end },
    { key = "mail", name = "Mail",
        frame = function() return MinimapCluster.IndicatorFrame end,
        buttons = function(f) return { f.MailFrame } end },
    { key = "compartment", name = "Addon menu",
        frame = function() return AddonCompartmentFrame end },
    { key = "daynight", name = "Day / night",
        frame = function() return MinimapCluster.DielFrame end },
    { key = "coords", name = "Coordinates",
        frame = function() return MinimapCluster.MinimapContainer.PlayerCoords end },
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
function ns.ElementMode(key)
    local m = ns.P.elements[key].mode
    if m == "show" and ns.P.clean then return "hover" end
    return m
end

local function Save(f)
    if saved[f] then return end
    local points = {}
    for i = 1, f:GetNumPoints() do points[i] = { f:GetPoint(i) } end
    saved[f] = { points = points, mouse = f:IsMouseEnabled() }
end

local function Restore(f)
    local s = saved[f]
    if not s then return end
    f:ClearAllPoints()
    for _, p in ipairs(s.points) do f:SetPoint(unpack(p)) end
    f:SetAlpha(1)
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
        Place(e, f)
        Paint(e, f)
    else
        Restore(f)
        SetMouse(e, f, true)
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
    if EventRegistry then
        EventRegistry:RegisterCallback("EditMode.Exit", Again, ns)
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, event, name)
        -- the clock exists once its addon loads
        if event == "PLAYER_ENTERING_WORLD" or name == "Blizzard_TimeManager" then Apply() end
    end)
end

ns.Module(Start, Apply)
