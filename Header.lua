-------------------------------------------------------------------------------
-- TidyMap - The header: TidyMap's own zone name and clock
--
-- Its own frames, so they can sit anywhere around the map without moving
-- Blizzard's. Blizzard still does the work: the zone text and its PvP color
-- come from Blizzard's own Minimap_Update (hooked), the time from
-- GameTime_GetTime (local or realm time, 12 / 24 h, as set in Blizzard's
-- clock), and a click on the clock does what Blizzard's clock does.
-------------------------------------------------------------------------------

local _, ns = ...
local Flaty = LibStub("LibFlatyUI-1.0")

local FLAT = "Interface\\Buttons\\WHITE8X8"
local GAP = 3     -- between the map and a piece, and between two pieces
local PAD_X, PAD_Y = 8, 3

local function On() return ns.P and ns.P.enabled and ns.P.header.on end

-------------------------------------------------------------------------------
-- Background: none, flat (the map's corner shape) or pill (round ends).
-- Two layers: the border (the map's border color) and the plate.
-------------------------------------------------------------------------------
local function Layer(f, sub)
    return {
        l = f:CreateTexture(nil, "BACKGROUND", nil, sub),
        c = f:CreateTexture(nil, "BACKGROUND", nil, sub),
        r = f:CreateTexture(nil, "BACKGROUND", nil, sub),
    }
end

-- one layer of w x h, centered on the frame
local function PaintLayer(L, f, kind, w, h, color)
    if not color or kind == "none" then
        L.l:Hide() L.c:Hide() L.r:Hide()
        return
    end
    for _, t in pairs(L) do t:SetVertexColor(color[1], color[2], color[3], color[4]) end
    L.c:ClearAllPoints()
    if kind == "pill" then
        -- half circles at both ends, a plain middle
        local round = Flaty.GetShape("r100").mask
        local cap = h / 2
        L.l:SetTexture(round) L.l:SetTexCoord(0, 0.5, 0, 1)
        L.r:SetTexture(round) L.r:SetTexCoord(0.5, 1, 0, 1)
        L.c:SetTexture(FLAT) L.c:SetTexCoord(0, 1, 0, 1)
        L.c:SetSize(math.max(0, w - 2 * cap), h)
        L.c:SetPoint("CENTER", f, "CENTER")
        L.l:SetSize(cap, h) L.l:ClearAllPoints() L.l:SetPoint("RIGHT", L.c, "LEFT")
        L.r:SetSize(cap, h) L.r:ClearAllPoints() L.r:SetPoint("LEFT", L.c, "RIGHT")
        L.l:Show() L.c:Show() L.r:Show()
    else
        L.c:SetTexture(Flaty.GetShape(Flaty.Rounded(ns.P.corners)).mask)
        L.c:SetTexCoord(0, 1, 0, 1)
        L.c:SetSize(w, h)
        L.c:SetPoint("CENTER", f, "CENTER")
        L.l:Hide() L.r:Hide()
        L.c:Show()
    end
end

-------------------------------------------------------------------------------
-- The two pieces
-------------------------------------------------------------------------------
local function NewPiece(key)
    local f = CreateFrame("Button", nil, Minimap)
    f:SetFrameLevel(Minimap:GetFrameLevel() + 10)
    f.key = key
    f.edge = Layer(f, -8)
    f.plate = Layer(f, -7)
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetPoint("CENTER")
    f:Hide()
    return f
end

local zone, clock = NewPiece("zone"), NewPiece("clock")
local pieces = { zone, clock }

-- the zone: not clickable, so clicks reach the map (pings)
zone:EnableMouse(false)

-- the clock: Blizzard's own click (its clock settings, or stop the alarm)
-- and tooltip (local and realm time)
clock:RegisterForClicks("LeftButtonUp")
clock:SetScript("OnClick", function()
    if TimeManagerClockButton and TimeManagerClockButton_OnClick then
        TimeManagerClockButton_OnClick(TimeManagerClockButton)
    end
end)
clock:SetScript("OnEnter", function(self)
    if not GameTime_UpdateTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTime_UpdateTooltip()
    GameTooltip:Show()
end)
clock:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function Cfg(f) return ns.P.header[f.key] end
local function Mode(f) return ns.EffectiveMode(Cfg(f).mode) end

for _, f in ipairs(pieces) do
    ns.faders[#ns.faders + 1] = { frame = f, mode = function() return On() and Mode(f) or "hide" end }
end

local function UpdateZoneText()
    zone.text:SetText(MinimapZoneText and MinimapZoneText:GetText() or GetMinimapZoneText())
    local c = Cfg(zone)
    if c.pvp and MinimapZoneText then
        zone.text:SetTextColor(MinimapZoneText:GetTextColor())
    else
        zone.text:SetTextColor(c.color.r, c.color.g, c.color.b, c.color.a or 1)
    end
end

local function UpdateClockText()
    if GameTime_GetTime then clock.text:SetText((GameTime_GetTime(true))) end
    local c = Cfg(clock).color
    clock.text:SetTextColor(c.r, c.g, c.b, c.a or 1)
end

-- Size to the text, background, and the alpha / mouse of its mode
local function Paint(f)
    local t = ns.P.texts
    Flaty.SetFontFile(f.text, t.font, f.key == "zone" and t.zone or t.clock, t.outline)
    local w = (f.text:GetStringWidth() or 0) + 2 * PAD_X
    local h = (f.text:GetStringHeight() or 10) + 2 * PAD_Y
    f:SetSize(w, h)
    local c = Cfg(f)
    local bg = { c.bgColor.r, c.bgColor.g, c.bgColor.b, c.bgColor.a or 1 }
    PaintLayer(f.plate, f, c.bg, w, h, bg)
    PaintLayer(f.edge, f, c.bg, w + 2, h + 2, ns.BorderColor())

    local mode = Mode(f)
    if ns.IsEditing() then
        f:SetAlpha(mode == "hide" and 0.35 or 1)
    elseif mode == "show" then
        f:SetAlpha(1)
    elseif mode == "hover" then
        f:SetAlpha(ns.HoverAlpha())
    else
        f:SetAlpha(0)
    end
    if f == clock then f:EnableMouse(mode ~= "hide" or ns.IsEditing()) end
end

-- Top or bottom, outside or inside, plus the extra distance. Two pieces in
-- the same place stack: the second one further out (or further in).
local function Place(f, under)
    local c = Cfg(f)
    local top, out = c.place == "top", c.side == "outside"
    local d = GAP + c.offset
    f:ClearAllPoints()
    if under then
        if top == out then
            f:SetPoint("BOTTOM", under, "TOP", 0, GAP)
        else
            f:SetPoint("TOP", under, "BOTTOM", 0, -GAP)
        end
    elseif top then
        if out then f:SetPoint("BOTTOM", Minimap, "TOP", 0, d)
        else f:SetPoint("TOP", Minimap, "TOP", 0, -d) end
    else
        if out then f:SetPoint("TOP", Minimap, "BOTTOM", 0, -d)
        else f:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, d) end
    end
end

local function Apply()
    if not On() then
        for _, f in ipairs(pieces) do f:Hide() end
        return
    end
    UpdateZoneText()
    UpdateClockText()
    for _, f in ipairs(pieces) do
        f:Show()
        Paint(f)
    end
    Place(zone)
    local z, c = Cfg(zone), Cfg(clock)
    local same = z.place == c.place and z.side == c.side and Mode(zone) ~= "hide"
    Place(clock, same and zone or nil)
end
ns.ApplyHeader = Apply

local function Start()
    if Minimap_Update then
        hooksecurefunc("Minimap_Update", function()
            if On() then
                UpdateZoneText()
                Paint(zone)
            end
        end)
    end
    -- the clock text, once a second (only while it shows)
    C_Timer.NewTicker(1, function()
        if On() and clock:IsShown() then
            local before = clock.text:GetText()
            UpdateClockText()
            if clock.text:GetText() ~= before then Paint(clock) end
        end
    end)
end

ns.Module(Start, Apply)
