-------------------------------------------------------------------------------
-- TidyMap - Blizzard's icons around the minimap (zone, clock, calendar,
-- tracking, mail, addon menu, day / night, coordinates)
--
-- Each one sits on the edge of the map's shape, at an angle, and is shown,
-- shown on hover or hidden. Plain frame calls only: SetPoint to place them,
-- SetAlpha to fade them (so Blizzard's own Show / Hide still decide when
-- they exist, e.g. mail), and the places Blizzard re-anchors them are
-- followed with hooksecurefunc. The texts (zone, clock, coordinates) are
-- Blizzard's own font strings in the Texts page's style. Turned off, every
-- icon gets its own place and look back.
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
        -- Blizzard's text sits left-aligned at the button's left side
        center = true,
        -- the bar behind the text (a nine-slice frame drawn over the
        -- button's own textures, so over the flat plate too)
        decor = function(f) return { f.StateTexture, f.BorderTop } end },
    { key = "clock", name = "Clock",
        frame = function() return TimeManagerClockButton end,
        text = function() return TimeManagerClockTicker end },
    { key = "calendar", name = "Calendar",
        frame = function() return GameTimeFrame end },
    { key = "tracking", name = "Tracking",
        frame = function() return MinimapCluster.Tracking end,
        buttons = function(f) return { f.Button } end,
        decor = function(f) return { f.Background } end },
    -- the holder always exists; the envelope only shows with mail, so the
    -- flat plate goes on the envelope (and hides with it)
    { key = "mail", name = "Mail",
        frame = function() return MinimapCluster.IndicatorFrame end,
        buttons = function(f) return { f.MailFrame } end,
        plateOn = function(f) return f.MailFrame end,
        -- the envelope picture is smaller than its frame, in its corner
        plateFit = function(f) return f.MailFrame and f.MailFrame.MailIcon end },
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

-- The mode an icon is in: Clean mode turns "show" into "hover". The
-- coordinates only exist while the game's own option shows them.
function ns.ElementMode(key)
    if key == "coords" and not C_CVar.GetCVarBool("minimapShowPlayerCoords") then return "hide" end
    local m = ns.P.elements[key].mode
    if m == "show" and ns.P.clean then return "hover" end
    return m
end

function ns.IsEditing() return editing end

local function Save(f)
    if saved[f] then return end
    local points = {}
    for i = 1, f:GetNumPoints() do points[i] = { f:GetPoint(i) } end
    saved[f] = { points = points, mouse = f:IsMouseEnabled(), alpha = f:GetAlpha(), scale = f:GetScale(),
        level = f:GetFrameLevel() }
end

local function Restore(f)
    local s = saved[f]
    if not s then return end
    f:SetScale(s.scale or 1)
    f:SetFrameLevel(s.level)
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
    -- some icons draw on a part of their frame (mail: the envelope), and
    -- fit the plate to their picture
    local fit = e.plateFit and e.plateFit(f)
    f = e.plateOn and e.plateOn(f) or f
    if not f then return end
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
        w, h, anchor = tw + 8, (text:GetStringHeight() or 10) + 2, text
    else
        local box = fit or f
        w, h = box:GetSize()
        anchor = box
    end
    local s = ns.P.elements[e.key]
    w, h = math.max(2, w + 2 * s.pad), math.max(2, h + 2 * s.pad)
    local mask = Flaty.GetShape(Flaty.Rounded(ns.PlateCorners(s))).mask
    local bg = s.bgColor
    p.bg:SetTexture(mask)
    p.bg:SetVertexColor(bg.r, bg.g, bg.b, bg.a or 1)
    p.bg:SetSize(w, h)
    p.bg:ClearAllPoints()
    p.bg:SetPoint("CENTER", anchor, "CENTER")
    p.bg:Show()
    local c = ns.PlateEdgeColor(s)
    p.edge:SetShown(c ~= nil)
    if c then
        p.edge:SetTexture(mask)
        p.edge:SetVertexColor(c[1], c[2], c[3], c[4])
        p.edge:SetSize(w + 2 * s.edge, h + 2 * s.edge)
        p.edge:ClearAllPoints()
        p.edge:SetPoint("CENTER", anchor, "CENTER")
    end
end

-------------------------------------------------------------------------------
-- Texts: Blizzard's font strings in the Texts page's style. The zone keeps
-- Blizzard's PvP colors unless a color of its own is picked.
-------------------------------------------------------------------------------
local fonts = {}   -- [font string] = Blizzard's own look

local function StyleText(e, f, on)
    local fs = e.text and e.text(f)
    if not fs then return end
    local b = fonts[fs]
    if not b then
        local points = {}
        for i = 1, fs:GetNumPoints() do points[i] = { fs:GetPoint(i) } end
        b = { font = { fs:GetFont() }, shadow = { fs:GetShadowColor() }, offset = { fs:GetShadowOffset() },
            color = { fs:GetTextColor() }, points = points, justify = fs:GetJustifyH(), width = fs:GetWidth() }
        fonts[fs] = b
    end
    local t = on and ns.P.texts[e.key]
    -- centered in its button (and so in its background), the button's width
    if e.center then
        fs:ClearAllPoints()
        if t then
            fs:SetPoint("CENTER", f, "CENTER")
            fs:SetWidth(f:GetWidth() - 8)
            fs:SetJustifyH("CENTER")
        else
            for _, p in ipairs(b.points) do fs:SetPoint(unpack(p)) end
            fs:SetWidth(b.width)
            fs:SetJustifyH(b.justify)
        end
    end
    if t then
        Flaty.SetFontFile(fs, t.font, t.size, t.outline)
        if t.shadow then
            local s = t.shadowColor
            fs:SetShadowColor(s.r, s.g, s.b, s.a or 1)
            fs:SetShadowOffset(t.shadowX, t.shadowY)
        else
            fs:SetShadowOffset(0, 0)
        end
    else
        fs:SetFont(unpack(b.font))
        fs:SetShadowColor(unpack(b.shadow))
        fs:SetShadowOffset(unpack(b.offset))
    end
    if e.key == "zone" then
        -- Blizzard's colors come from its own update
        if t and not t.pvp then
            local c = t.color
            fs:SetTextColor(c.r, c.g, c.b, c.a or 1)
        elseif Minimap_Update then
            Minimap_Update()
        end
    elseif t then
        fs:SetTextColor(t.color.r, t.color.g, t.color.b, t.color.a or 1)
    else
        fs:SetTextColor(unpack(b.color))
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
        -- above the map (some sit lower, e.g. the addon menu)
        f:SetFrameLevel(math.max(saved[f].level, Minimap:GetFrameLevel() + 5))
        Place(e, f)
        Paint(e, f)
        StyleText(e, f, true)
        Decor(e, f, s.look ~= "flat")
        PaintPlate(e, f, s.look == "flat")
    else
        Restore(f)
        SetMouse(e, f, true)
        StyleText(e, f, false)
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
    if ns.ApplyVisibility then ns.ApplyVisibility() end
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
    -- after Edit Mode closes. A post-hook, not an EventRegistry callback: a
    -- callback would run inside Blizzard's own exit and taint what follows
    -- (protected actions then get blocked, blamed on TidyMap)
    if EditModeManagerFrame and EditModeManagerFrame.ExitEditMode then
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", Again)
    end
    -- the zone's own color, after Blizzard sets its PvP color
    if Minimap_Update then
        hooksecurefunc("Minimap_Update", function()
            local t = On() and ns.P.texts.zone
            if t and not t.pvp and MinimapZoneText then
                MinimapZoneText:SetTextColor(t.color.r, t.color.g, t.color.b, t.color.a or 1)
            end
        end)
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("CVAR_UPDATE")
    f:SetScript("OnEvent", function(_, event, name)
        -- the clock exists once its addon loads; the coordinates follow the
        -- game's option
        if event == "PLAYER_ENTERING_WORLD" or name == "Blizzard_TimeManager"
            or (event == "CVAR_UPDATE" and (name == "minimapShowPlayerCoords" or name == "coordsByTenths")) then
            Apply()
        end
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
